"""Regression tests for authorization, OTP proofs, and dashboard cookies."""

import pytest
from django.conf import settings
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken, TokenError

from factories import (
    RestaurantProfileFactory,
    RestaurantStaffProfileFactory,
    UserFactory,
)
from users.models import EmailVerification
from users.registration_proofs import issue_registration_proof
from users.serializers import RegistrationSerializer, VerifyOTPSerializer

pytestmark = pytest.mark.django_db
BASE = "/api/v1/users/auth"
ORIGIN = "https://dashboard.example.test"


def browser_settings(settings):
    settings.BROWSER_SESSION_ORIGINS = [ORIGIN]


def test_owner_cannot_assign_protected_profile_fields(restaurant_api, restaurant_user):
    profile = restaurant_user.restaurant_profile
    profile.is_approved = False
    profile.save(update_fields=["is_approved"])
    response = restaurant_api.put(
        f"{BASE}/profile/",
        {
            "first_name": "Should not save",
            "profile": {"is_approved": True, "rating": "5.00"},
        },
        format="json",
    )
    assert response.status_code == 400
    profile.refresh_from_db()
    restaurant_user.refresh_from_db()
    assert not profile.is_approved
    assert restaurant_user.first_name != "Should not save"


def test_owner_can_edit_allowed_profile_fields(restaurant_api, restaurant_user):
    response = restaurant_api.put(
        f"{BASE}/profile/",
        {
            "profile": {"restaurant_name": "New name"},
        },
        format="json",
    )
    assert response.status_code == 200
    restaurant_user.restaurant_profile.refresh_from_db()
    assert restaurant_user.restaurant_profile.restaurant_name == "New name"


def test_owner_cannot_move_staff_to_another_restaurant(restaurant_api, restaurant_user):
    staff = RestaurantStaffProfileFactory(restaurant=restaurant_user.restaurant_profile)
    victim = RestaurantProfileFactory()
    response = restaurant_api.patch(
        f"{BASE}/staff/{staff.pk}/", {"restaurant": victim.pk}, format="json"
    )
    assert response.status_code == 400
    staff.refresh_from_db()
    assert staff.restaurant_id == restaurant_user.restaurant_profile.pk


def verified_record(email):
    return EmailVerification.objects.create(
        email=email,
        otp="verified-hash",
        is_verified=True,
        expires_at=timezone.now() + timezone.timedelta(minutes=20),
    )


def payload(email, token=None):
    data = dict(
        email=email,
        first_name="New",
        last_name="Owner",
        user_type="restaurant",
        password="StrongPass123!",
        password2="StrongPass123!",
        restaurant_name="Restaurant",
        business_license="security-license",
        address="Kampala",
        latitude=0.3476,
        longitude=32.5825,
    )
    if token is not None:
        data["registration_token"] = token
    return data


def test_verified_database_flag_alone_does_not_authorize_registration():
    verified_record("victim@example.test")
    serializer = RegistrationSerializer(data=payload("victim@example.test"))
    assert not serializer.is_valid()
    assert "registration_token" in serializer.errors


def test_proof_is_bound_to_contact_and_cannot_be_tampered_with():
    record = verified_record("owner@example.test")
    proof = issue_registration_proof(record, "email")
    for email, token in [
        ("other@example.test", proof),
        (record.email, proof + "tampered"),
    ]:
        serializer = RegistrationSerializer(data=payload(email, token))
        assert not serializer.is_valid()
        assert "registration_token" in serializer.errors


def test_proof_is_rechecked_and_consumed_inside_registration_transaction(monkeypatch):
    monkeypatch.setattr(
        "users.tasks.send_templated_email_task.delay", lambda *args: None
    )
    record = verified_record("owner@example.test")
    data = payload(record.email, issue_registration_proof(record, "email"))
    first, concurrent = RegistrationSerializer(data=data), RegistrationSerializer(
        data=data
    )
    assert first.is_valid(), first.errors
    assert concurrent.is_valid(), concurrent.errors
    first.save()
    from rest_framework.exceptions import ValidationError

    with pytest.raises(ValidationError):
        concurrent.save()
    record.refresh_from_db()
    assert not record.is_verified


def test_expired_proof_is_rejected():
    record = verified_record("owner@example.test")
    proof = issue_registration_proof(record, "email")
    record.expires_at = timezone.now() - timezone.timedelta(seconds=1)
    record.save(update_fields=["expires_at"])
    serializer = RegistrationSerializer(data=payload(record.email, proof))
    assert not serializer.is_valid()


def test_otp_verification_returns_registration_credential():
    record = EmailVerification.objects.create(
        email="new@example.test", otp="", expires_at=timezone.now()
    )
    otp = record.generate_otp()
    serializer = VerifyOTPSerializer(data={"email": record.email, "otp": otp})
    assert serializer.is_valid(), serializer.errors
    assert serializer.save()["registration_token"]


def test_browser_session_cookie_rotation_and_logout(settings):
    browser_settings(settings)
    user = UserFactory()
    refresh = RefreshToken.for_user(user)
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {refresh.access_token}")
    response = client.post(
        f"{BASE}/browser/session/",
        {"refresh": str(refresh)},
        format="json",
        HTTP_ORIGIN=ORIGIN,
    )
    assert response.status_code == 200
    cookie = response.cookies[settings.BROWSER_REFRESH_COOKIE]
    assert cookie["httponly"] and cookie["secure"] and cookie["samesite"] == "None"
    assert "refresh" not in response.data
    with pytest.raises(TokenError):
        RefreshToken(str(refresh))
    client.credentials()
    response = client.post(
        f"{BASE}/browser/refresh/", {}, format="json", HTTP_ORIGIN=ORIGIN
    )
    assert response.status_code == 200 and response.data["access"]
    assert "refresh" not in response.data
    latest = response.cookies[settings.BROWSER_REFRESH_COOKIE].value
    response = client.post(
        f"{BASE}/browser/logout/", {}, format="json", HTTP_ORIGIN=ORIGIN
    )
    assert response.status_code == 200
    assert response.cookies[settings.BROWSER_REFRESH_COOKIE]["max-age"] == 0
    with pytest.raises(TokenError):
        RefreshToken(latest)


@pytest.mark.parametrize("endpoint", ["refresh", "logout"])
@pytest.mark.parametrize("origin", [None, "https://attacker.example.test"])
def test_cookie_endpoints_reject_untrusted_or_missing_origin(
    settings, endpoint, origin
):
    browser_settings(settings)
    headers = {"HTTP_ORIGIN": origin} if origin else {}
    response = APIClient().post(
        f"{BASE}/browser/{endpoint}/", {}, format="json", **headers
    )
    assert response.status_code == 403


def test_browser_session_rejects_another_users_refresh(settings):
    browser_settings(settings)
    client = APIClient()
    client.force_authenticate(UserFactory())
    foreign = RefreshToken.for_user(UserFactory())
    response = client.post(
        f"{BASE}/browser/session/",
        {"refresh": str(foreign)},
        format="json",
        HTTP_ORIGIN=ORIGIN,
    )
    assert response.status_code == 403


def test_disabled_user_cannot_refresh_browser_session(settings):
    browser_settings(settings)
    user = UserFactory(is_active=False)
    refresh = RefreshToken.for_user(user)
    client = APIClient()
    client.cookies[settings.BROWSER_REFRESH_COOKIE] = str(refresh)
    response = client.post(
        f"{BASE}/browser/refresh/", {}, format="json", HTTP_ORIGIN=ORIGIN
    )
    assert response.status_code == 401


def test_browser_logout_deactivates_only_this_users_device(settings):
    from push_notifications.models import WebPushDevice

    browser_settings(settings)
    user, other = UserFactory(), UserFactory()
    ours = WebPushDevice.objects.create(
        user=user,
        registration_id="https://push.example.test/ours",
        p256dh="key",
        auth="auth",
        browser="CHROME",
    )
    theirs = WebPushDevice.objects.create(
        user=other,
        registration_id="https://push.example.test/theirs",
        p256dh="key",
        auth="auth",
        browser="CHROME",
    )
    client = APIClient()
    client.cookies[settings.BROWSER_REFRESH_COOKIE] = str(RefreshToken.for_user(user))
    response = client.post(
        f"{BASE}/browser/logout/",
        {"registration_id": ours.registration_id},
        format="json",
        HTTP_ORIGIN=ORIGIN,
    )
    assert response.status_code == 200
    ours.refresh_from_db()
    theirs.refresh_from_db()
    assert not ours.active and theirs.active
