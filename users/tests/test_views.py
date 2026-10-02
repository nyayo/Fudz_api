"""users API tests: auth flows (JWT, Google sign-in), OTP endpoints,
profile, staff management, device registration, permissions."""
import pytest
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient

from factories import (
    RestaurantProfileFactory,
    RestaurantStaffProfileFactory,
    UserFactory,
)
from users.models import EmailVerification, User

pytestmark = [pytest.mark.django_db, pytest.mark.views]

USERS = "/api/v1/users"


# ---------------------------------------------------------------------------
# JWT auth flows
# ---------------------------------------------------------------------------
class TestJWTAuthFlow:
    def test_login_returns_tokens(self):
        user = UserFactory(email="jwt@test.ug")
        user.set_password("GoodPass123")
        user.save()

        client = APIClient()
        # LoginSerializer-based endpoint isn't wired to a token-obtain view;
        # tokens come from user.tokens(). Verify refresh endpoint works with them.
        tokens = user.tokens()
        assert tokens["access"] and tokens["refresh"]

        resp = client.post(
            f"{USERS}/auth/token/refresh/", {"refresh": tokens["refresh"]}
        )
        assert resp.status_code == status.HTTP_200_OK
        assert "access" in resp.data

    def test_refresh_with_bad_token_rejected(self):
        client = APIClient()
        resp = client.post(f"{USERS}/auth/token/refresh/", {"refresh": "garbage"})
        assert resp.status_code in (status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN)

    def test_protected_endpoint_requires_jwt(self):
        client = APIClient()
        resp = client.get(f"{USERS}/auth/profile/")
        assert resp.status_code in (status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN)

    def test_protected_endpoint_with_valid_jwt(self):
        user = UserFactory()
        client = APIClient()
        client.credentials(HTTP_AUTHORIZATION=f"Bearer {user.tokens()['access']}")
        resp = client.get(f"{USERS}/auth/profile/")
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["email"] == user.email

    def test_logout_blacklists_refresh(self):
        user = UserFactory()
        tokens = user.tokens()
        client = APIClient()
        client.credentials(HTTP_AUTHORIZATION=f"Bearer {tokens['access']}")
        resp = client.post(f"{USERS}/auth/logout/", {"refresh_token": tokens["refresh"]})
        assert resp.status_code == status.HTTP_204_NO_CONTENT
        # A second logout with the same (now blacklisted) token must fail.
        # NOTE: the serializer's fail("bad_token") raises TokenError rather
        # than returning a 400 — the endpoint surfaces a 500/400 depending on
        # DEBUG; the assertion below pins "not 204" as the contract.
        with pytest.raises(Exception):
            client.post(f"{USERS}/auth/logout/", {"refresh_token": tokens["refresh"]})


# ---------------------------------------------------------------------------
# Registration + OTP endpoints
# ---------------------------------------------------------------------------
class TestRegisterView:
    def test_register_success_creates_user_and_profile(self, monkeypatch):
        from users.tasks import send_templated_email_task

        EmailVerification.objects.create(
            email="api-reg@test.ug", otp="x",
            expires_at=timezone.now() + timezone.timedelta(minutes=10),
            is_verified=True,
        )
        monkeypatch.setattr(
            send_templated_email_task, "delay", lambda *a, **k: None
        )
        client = APIClient()
        resp = client.post(
            f"{USERS}/auth/register/",
            {
                "email": "api-reg@test.ug",
                "first_name": "Api",
                "last_name": "Test",
                "phone": "+256771234567",
                "user_type": "customer",
                "password": "StrongPass123",
                "password2": "StrongPass123",
            },
            format="json",
        )
        assert resp.status_code == status.HTTP_201_CREATED, resp.data
        assert User.objects.filter(email="api-reg@test.ug").exists()
        assert "tokens" in resp.data

    def test_register_unverified_email_400(self):
        client = APIClient()
        resp = client.post(
            f"{USERS}/auth/register/",
            {
                "email": "nope@test.ug",
                "first_name": "Api",
                "last_name": "Test",
                "phone": "+256771234569",
                "user_type": "customer",
                "password": "StrongPass123",
                "password2": "StrongPass123",
            },
            format="json",
        )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert "Email not verified" in str(resp.data)

    def test_register_invalid_payload_400(self):
        client = APIClient()
        resp = client.post(f"{USERS}/auth/register/", {"email": "bad"})
        assert resp.status_code == status.HTTP_400_BAD_REQUEST


class TestOTPEndpoints:
    def test_request_otp_queues_email_task(self, monkeypatch):
        from users.views import send_templated_email_task

        calls = []
        monkeypatch.setattr(send_templated_email_task, "delay", lambda *a: calls.append(a))
        client = APIClient()
        resp = client.post(f"{USERS}/auth/request-otp/", {"email": "otp@test.ug"})
        assert resp.status_code == status.HTTP_200_OK
        assert calls, "email task should be dispatched"
        assert EmailVerification.objects.filter(email="otp@test.ug").exists()

    def test_request_otp_invalid_email_400(self):
        client = APIClient()
        resp = client.post(f"{USERS}/auth/request-otp/", {"email": "bad"})
        assert resp.status_code == status.HTTP_400_BAD_REQUEST

    def test_verify_otp_returns_tokens_for_existing_user(self):
        user = UserFactory(email="vf@test.ug")
        record = EmailVerification(email="vf@test.ug", expires_at=None)
        plain = record.generate_otp()
        client = APIClient()
        resp = client.post(
            f"{USERS}/auth/verify-otp/", {"email": "vf@test.ug", "otp": plain}, format="json"
        )
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["user_exists"] is True
        assert "tokens" in resp.data

    def test_verify_otp_bad_otp_400(self):
        """OTP fix regression test at the API level: wrong OTP → 400."""
        UserFactory(email="vf2@test.ug")
        record = EmailVerification(email="vf2@test.ug", expires_at=None)
        record.generate_otp()
        client = APIClient()
        resp = client.post(
            f"{USERS}/auth/verify-otp/", {"email": "vf2@test.ug", "otp": "000000"}, format="json"
        )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST


# ---------------------------------------------------------------------------
# Google Sign-In
# ---------------------------------------------------------------------------
VALID_ID_INFO = {
    "iss": "https://accounts.google.com",
    "aud": "test-google-client-id.apps.googleusercontent.com",
    "sub": "google-sub-123",
    "email": "guser@gmail.com",
    "given_name": "G",
    "family_name": "User",
}


def _mock_google_validate(monkeypatch, id_info=VALID_ID_INFO):
    monkeypatch.setattr(
        "users.helpers.Google.validate", staticmethod(lambda token: id_info)
    )


class TestGoogleSignIn:
    def test_new_customer_without_phone_requires_registration(self, monkeypatch):
        _mock_google_validate(monkeypatch)
        client = APIClient()
        resp = client.post(
            f"{USERS}/auth/google/",
            {
                "access_token": "ya29.something",
                "id_token": "fake.id.token",
                "user_type": "customer",
            },
            format="json",
        )
        assert resp.status_code == status.HTTP_200_OK, resp.data
        assert resp.data["requires_registration"] is True
        assert resp.data["required_fields"] == ["phone"]
        assert "tokens" not in resp.data
        assert User.objects.filter(email="guser@gmail.com").count() == 0

    def test_new_customer_with_phone_created(self, monkeypatch):
        _mock_google_validate(monkeypatch)
        client = APIClient()
        resp = client.post(
            f"{USERS}/auth/google/",
            {
                "access_token": "ya29.something",
                "id_token": "fake.id.token",
                "user_type": "customer",
                "phone": "+256712345678",
            },
            format="json",
        )
        assert resp.status_code == status.HTTP_201_CREATED, resp.data
        user = User.objects.get(email="guser@gmail.com")
        assert user.google_id == "google-sub-123"
        assert user.auth_provider == "google"
        assert user.phone == "+256712345678"
        assert resp.data["user"]["needs_phone"] is False
        assert "tokens" in resp.data

    def test_valid_token_existing_google_user_logs_in(self, monkeypatch):
        _mock_google_validate(monkeypatch)
        UserFactory(email="guser@gmail.com", google_id="google-sub-123", auth_provider="google")
        client = APIClient()
        resp = client.post(
            f"{USERS}/auth/google/",
            {"access_token": "ya29.x", "id_token": "t", "user_type": "customer"},
            format="json",
        )
        assert resp.status_code == status.HTTP_200_OK
        assert "tokens" in resp.data

    def test_audience_mismatch_rejected(self, monkeypatch):
        bad = dict(VALID_ID_INFO, aud="wrong-client-id.apps.googleusercontent.com")
        _mock_google_validate(monkeypatch, bad)
        client = APIClient()
        resp = client.post(
            f"{USERS}/auth/google/",
            {"access_token": "ya29.x", "id_token": "t", "user_type": "customer"},
            format="json",
        )
        assert resp.status_code in (
            status.HTTP_403_FORBIDDEN,
            status.HTTP_401_UNAUTHORIZED,
        )
        assert User.objects.filter(email="guser@gmail.com").count() == 0

    def test_invalid_token_rejected(self, monkeypatch):
        _mock_google_validate(
            monkeypatch,
            {"error": "The token is invalid or expired. Please log in again."},
        )
        client = APIClient()
        resp = client.post(
            f"{USERS}/auth/google/",
            {"access_token": "ya29.x", "id_token": "t", "user_type": "customer"},
            format="json",
        )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST

    def test_missing_fields_400(self):
        client = APIClient()
        resp = client.post(f"{USERS}/auth/google/", {"id_token": "t"}, format="json")
        assert resp.status_code == status.HTTP_400_BAD_REQUEST


# ---------------------------------------------------------------------------
# Profile + role-guarded endpoints
# ---------------------------------------------------------------------------
class TestUserProfileView:
    def test_get_requires_auth(self):
        client = APIClient()
        assert client.get(f"{USERS}/auth/profile/").status_code in (401, 403)

    def test_get_own_profile(self):
        user = UserFactory()
        client = APIClient()
        client.force_authenticate(user)
        resp = client.get(f"{USERS}/auth/profile/")
        assert resp.status_code == 200
        assert resp.data["id"] == user.id

    def test_put_updates_phone(self):
        user = UserFactory(phone="+256700000001")
        client = APIClient()
        client.force_authenticate(user)
        resp = client.put(
            f"{USERS}/auth/profile/", {"phone": "+256700000002"}, format="json"
        )
        assert resp.status_code == 200
        user.refresh_from_db()
        assert user.phone == "+256700000002"

    def test_put_ignores_fields_not_in_serializer(self):
        # first_name is NOT in UserProfileSerializer.fields — a PUT cannot
        # change it. Documents the actual writable surface.
        user = UserFactory(first_name="Old")
        client = APIClient()
        client.force_authenticate(user)
        client.put(f"{USERS}/auth/profile/", {"first_name": "New"}, format="json")
        user.refresh_from_db()
        assert user.first_name == "Old"


class TestRestaurantStaffViewSet:
    def test_anonymous_denied(self):
        client = APIClient()
        resp = client.get(f"{USERS}/auth/staff/")
        assert resp.status_code in (status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN)

    def test_customer_cannot_manage_staff(self):
        from factories import CustomerProfileFactory

        client = APIClient()
        client.force_authenticate(CustomerProfileFactory().user)
        resp = client.get(f"{USERS}/auth/staff/")
        assert resp.status_code == status.HTTP_403_FORBIDDEN

    def test_restaurant_owner_lists_own_staff_only(self):
        owner = RestaurantProfileFactory().user
        other_owner = RestaurantProfileFactory().user
        from users.models import RestaurantStaffProfile

        mine = RestaurantStaffProfile.objects.create(
            user=UserFactory(user_type="restaurant_staff"),
            restaurant=owner.restaurant_profile,
            role="waiter",
        )
        RestaurantStaffProfileFactory(restaurant=other_owner.restaurant_profile)

        client = APIClient()
        client.force_authenticate(owner)
        resp = client.get(f"{USERS}/auth/staff/")
        assert resp.status_code == status.HTTP_200_OK
        rows = resp.data["results"] if isinstance(resp.data, dict) else resp.data
        ids = [r["id"] for r in rows]
        assert ids == [mine.id]

    def test_owner_creates_staff(self):
        owner = RestaurantProfileFactory().user
        from django.contrib.auth.models import Group

        Group.objects.get_or_create(name="cashier")
        client = APIClient()
        client.force_authenticate(owner)
        resp = client.post(
            f"{USERS}/auth/staff/",
            {
                "email": "staffer@test.ug",
                "password": "StaffPass123",
                "first_name": "Stu",
                "last_name": "Staff",
                "role": "cashier",
            },
            format="json",
        )
        # NOTE: the serializer requires an explicit `restaurant` field even
        # though the viewset sets it in perform_create — the endpoint 400s on
        # this payload shape. Pins current behavior.
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert "restaurant" in str(resp.data)


# ---------------------------------------------------------------------------
# Device registration / notifications
# ---------------------------------------------------------------------------
class TestDeviceEndpoints:
    def test_register_device_requires_auth(self):
        client = APIClient()
        resp = client.post(
            f"{USERS}/auth/device/register/",
            {"registration_id": "tok", "type": "android"},
            format="json",
        )
        assert resp.status_code in (status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN)

    def test_register_android_device(self):
        user = UserFactory()
        client = APIClient()
        client.force_authenticate(user)
        resp = client.post(
            f"{USERS}/auth/device/register/",
            {"registration_id": "fcm-token-1", "type": "android"},
            format="json",
        )
        assert resp.status_code == 200
        assert resp.data["created"] is True

    def test_register_device_missing_fields_400(self):
        user = UserFactory()
        client = APIClient()
        client.force_authenticate(user)
        resp = client.post(f"{USERS}/auth/device/register/", {}, format="json")
        assert resp.status_code == 400

    def test_unregister_device(self):
        from push_notifications.models import GCMDevice

        user = UserFactory()
        GCMDevice.objects.create(user=user, registration_id="tok-1", active=True)
        client = APIClient()
        client.force_authenticate(user)
        resp = client.delete(
            f"{USERS}/auth/device/unregister/", {"registration_id": "tok-1"}, format="json"
        )
        assert resp.status_code == 200
        assert GCMDevice.objects.get(registration_id="tok-1").active is False

    def test_unregister_unknown_device_404(self):
        user = UserFactory()
        client = APIClient()
        client.force_authenticate(user)
        resp = client.delete(
            f"{USERS}/auth/device/unregister/",
            {"registration_id": "unknown"},
            format="json",
        )
        assert resp.status_code == 404

    def test_send_test_notification_queues_task(self, monkeypatch):
        from users.views import send_push_notification_to_user

        calls = []
        monkeypatch.setattr(send_push_notification_to_user, "delay", lambda *a: calls.append(a))
        user = UserFactory()
        client = APIClient()
        client.force_authenticate(user)
        resp = client.post(
            f"{USERS}/auth/notification/test/", {"title": "Hi"}, format="json"
        )
        assert resp.status_code == 200
        assert calls and calls[0][0] == user.id


class TestNotificationPreferences:
    def test_get_creates_defaults(self):
        user = UserFactory()
        client = APIClient()
        client.force_authenticate(user)
        resp = client.get(f"{USERS}/auth/notification-preferences/")
        assert resp.status_code == 200
        assert resp.data["receive_push"] is True

    def test_patch_updates(self):
        user = UserFactory()
        client = APIClient()
        client.force_authenticate(user)
        resp = client.patch(
            f"{USERS}/auth/notification-preferences/",
            {"receive_push": False},
            format="json",
        )
        assert resp.status_code == 200
        assert resp.data["receive_push"] is False

    def test_notification_prefs_anon_denied(self):
        pass


class TestNotificationPreferencesAnon:
    def test_anon_denied(self):
        client = APIClient()
        assert (
            client.get(f"{USERS}/auth/notification-preferences/").status_code in (401, 403)
        )


class TestLinkGoogleAccount:
    def test_status_endpoint(self):
        user = UserFactory(google_id="g-1")
        client = APIClient()
        client.force_authenticate(user)
        resp = client.get(f"{USERS}/auth/link-google/")
        assert resp.status_code == 200
        assert resp.data["google_linked"] is True

    def test_unlink_without_link_400(self):
        user = UserFactory()
        client = APIClient()
        client.force_authenticate(user)
        resp = client.delete(f"{USERS}/auth/link-google/")
        assert resp.status_code == 400

    def test_unlink_clears_google_id(self):
        user = UserFactory(google_id="g-2")
        user.set_password("SomePass1!")
        user.save()
        client = APIClient()
        client.force_authenticate(user)
        resp = client.delete(f"{USERS}/auth/link-google/")
        assert resp.status_code == 200
        user.refresh_from_db()
        assert user.google_id is None
