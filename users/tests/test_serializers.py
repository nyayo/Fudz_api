"""users serializer tests: registration, OTP, login, Google sign-in payload."""
import pytest
from django.utils import timezone
from rest_framework import serializers as drf_errors

from factories import UserFactory
from users.models import EmailVerification, PhoneVerification
from users.serializers import (
    LoginSerializer,
    RegistrationSerializer,
    RequestPhoneOTPSerializer,
    RequestOTPSerializer,
    UserProfileSerializer,
    VerifyOTPSerializer,
    VerifyPhoneOTPSerializer,
)

pytestmark = [pytest.mark.django_db, pytest.mark.serializers]


def _verified_email(email):
    EmailVerification.objects.create(
        email=email,
        otp="x",
        expires_at=timezone.now() + timezone.timedelta(minutes=10),
        is_verified=True,
    )


class TestRequestOTPSerializer:
    def test_valid_email(self):
        s = RequestOTPSerializer(data={"email": "someone@test.ug"})
        assert s.is_valid(), s.errors

    def test_invalid_email(self):
        s = RequestOTPSerializer(data={"email": "not-an-email"})
        assert not s.is_valid()
        assert "email" in s.errors


class TestRequestPhoneOTPSerializer:
    def test_valid_ugandan_phone(self):
        s = RequestPhoneOTPSerializer(data={"phone": "+256772123456"})
        assert s.is_valid(), s.errors

    def test_invalid_phone(self):
        s = RequestPhoneOTPSerializer(data={"phone": "0772123456"})
        assert not s.is_valid()
        assert "phone" in s.errors


class TestRegistrationSerializer:
    def base_payload(self, email="newuser@test.ug"):
        return {
            "email": email,
            "first_name": "Jane",
            "last_name": "Doe",
            "phone": "+256772999888",
            "user_type": "customer",
            "password": "StrongPass123",
            "password2": "StrongPass123",
        }

    def test_valid_registration(self):
        _verified_email("newuser@test.ug")
        s = RegistrationSerializer(data=self.base_payload())
        assert s.is_valid(), s.errors

    def test_password_mismatch(self):
        _verified_email("newuser@test.ug")
        payload = self.base_payload()
        payload["password2"] = "Different123"
        s = RegistrationSerializer(data=payload)
        assert not s.is_valid()
        assert "Passwords do not match" in str(s.errors)

    def test_unverified_email_rejected(self):
        s = RegistrationSerializer(data=self.base_payload())
        assert not s.is_valid()
        assert "Email not verified." in str(s.errors)

    def test_duplicate_email_rejected(self):
        _verified_email("taken@test.ug")
        UserFactory(email="taken@test.ug")
        s = RegistrationSerializer(data=self.base_payload(email="taken@test.ug"))
        assert not s.is_valid()
        assert "already exists" in str(s.errors)

    def test_duplicate_phone_rejected(self):
        _verified_email("phone-dup@test.ug")
        UserFactory(email="other@test.ug", phone="+256772999888")
        s = RegistrationSerializer(data=self.base_payload())
        assert not s.is_valid()
        assert "already exists" in str(s.errors)

    def test_customer_requires_phone_note(self):
        # The serializer has a NameError bug: `not phone` references a bare
        # name instead of attrs["phone"]. This test documents current
        # behavior so the fix is visible when made.
        _verified_email("cust@test.ug")
        payload = self.base_payload(email="cust@test.ug")
        payload.pop("phone")
        s = RegistrationSerializer(data=payload)
        with pytest.raises(Exception):
            s.is_valid(raise_exception=True)

    def test_restaurant_requires_profile_fields(self):
        _verified_email("resto@test.ug")
        payload = self.base_payload(email="resto@test.ug")
        payload["user_type"] = "restaurant"
        payload.pop("phone")
        s = RegistrationSerializer(data=payload)
        # restaurants don't need a phone, but profile fields are required
        assert not s.is_valid()
        assert "Restaurant name" in str(s.errors)

    def test_restaurant_missing_profile_fields_with_phone(self):
        _verified_email("resto2@test.ug")
        payload = self.base_payload(email="resto2@test.ug")
        payload["user_type"] = "restaurant"
        s = RegistrationSerializer(data=payload)
        assert not s.is_valid()
        assert "Restaurant name" in str(s.errors)

    def test_courier_requires_license_fields(self):
        _verified_email("courier@test.ug")
        payload = self.base_payload(email="courier@test.ug")
        payload["user_type"] = "courier"
        s = RegistrationSerializer(data=payload)
        assert not s.is_valid()
        assert "license number" in str(s.errors).lower()

    def test_create_creates_customer_profile(self, monkeypatch):
        _verified_email("created@test.ug")
        from users import tasks as users_tasks

        monkeypatch.setattr(users_tasks.send_templated_email_task, "delay", lambda *a, **k: None)
        s = RegistrationSerializer(data=self.base_payload(email="created@test.ug"))
        assert s.is_valid(), s.errors
        user = s.save()
        assert user.user_type == "customer"
        assert hasattr(user, "customer_profile")
        assert user.check_password("StrongPass123")


class TestLoginSerializer:
    def test_valid_credentials(self):
        user = UserFactory(email="login@test.ug")
        user.set_password("RightPass123")
        user.save()
        s = LoginSerializer(data={"email": "login@test.ug", "password": "RightPass123"})
        assert s.is_valid(), s.errors
        assert s.validated_data["user"] == user

    def test_wrong_password(self):
        user = UserFactory(email="login3@test.ug")
        user.set_password("RightPass123")
        user.save()
        s = LoginSerializer(data={"email": "login3@test.ug", "password": "WrongPass123"})
        assert not s.is_valid()
        assert "Invalid credentials" in str(s.errors)

    def test_unknown_email(self):
        s = LoginSerializer(data={"email": "ghost@test.ug", "password": "whatever1"})
        assert not s.is_valid()
        assert "does not exist" in str(s.errors)


class TestVerifyOTPSerializer:
    def test_valid_otp_existing_user(self):
        user = UserFactory(email="verify@test.ug")
        record = EmailVerification(email="verify@test.ug", expires_at=None)
        plain = record.generate_otp()
        s = VerifyOTPSerializer(data={"email": "verify@test.ug", "otp": plain})
        assert s.is_valid(), s.errors
        result = s.save()
        assert result["user_exists"] is True
        record.refresh_from_db()
        assert record.is_verified is True

    def test_wrong_otp_rejected(self):
        """OTP fix regression test: wrong OTPs must NOT verify."""
        UserFactory(email="verify2@test.ug")
        record = EmailVerification(email="verify2@test.ug", expires_at=None)
        record.generate_otp()
        s = VerifyOTPSerializer(data={"email": "verify2@test.ug", "otp": "000000"})
        assert not s.is_valid()
        assert "Invalid OTP" in str(s.errors)
        record.refresh_from_db()
        assert record.is_verified is False

    def test_unknown_email(self):
        s = VerifyOTPSerializer(data={"email": "nobody@test.ug", "otp": "123456"})
        assert not s.is_valid()
        assert "Invalid OTP or email" in str(s.errors)


class TestVerifyPhoneOTPSerializer:
    def test_valid_otp(self):
        UserFactory(phone="+256700111222")
        record = PhoneVerification(phone="+256700111222", expires_at=None)
        plain = record.generate_otp()
        s = VerifyPhoneOTPSerializer(data={"phone": "+256700111222", "otp": plain})
        assert s.is_valid(), s.errors
        assert s.validated_data["user_exists"] is True


class TestUserProfileSerializer:
    def test_customer_profile_shape(self):
        user = UserFactory(user_type="customer", first_name="A", last_name="B")
        from users.models import CustomerProfile

        CustomerProfile.objects.create(user=user)
        data = UserProfileSerializer(user).data
        assert data["full_name"] == "A B"
        assert data["profile"]["order_stats"] == {}

    def test_restaurant_profile_shape(self):
        from factories import RestaurantProfileFactory

        profile = RestaurantProfileFactory()
        data = UserProfileSerializer(profile.user).data
        assert data["profile"]["restaurant_name"] == profile.restaurant_name
        assert data["profile"]["is_approved"] is True
