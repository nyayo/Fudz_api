"""users model tests: constraints, uniqueness, username generation, OTP logic."""
import pytest
from django.db import IntegrityError

from factories import (
    AddressFactory,
    CourierProfileFactory,
    CustomerProfileFactory,
    RestaurantProfileFactory,
    RestaurantStaffProfileFactory,
    UserFactory,
)
from users.models import (
    Address,
    CustomerProfile,
    EmailVerification,
    RestaurantProfile,
    User,
)

pytestmark = [pytest.mark.django_db, pytest.mark.models]


class TestUserModel:
    def test_create_minimal_customer(self):
        user = UserFactory(user_type="customer")
        assert user.pk is not None
        assert user.is_verified is True
        assert user.auth_provider == "email"

    def test_email_unique(self):
        UserFactory(email="dupe@test.ug")
        with pytest.raises(IntegrityError):
            UserFactory(email="dupe@test.ug")

    def test_google_id_unique(self):
        UserFactory(google_id="gid-1")
        with pytest.raises(IntegrityError):
            UserFactory(google_id="gid-1")

    def test_username_auto_generated_from_email(self):
        user = UserFactory(user_type="customer")
        assert user.username.startswith("customer_")
        assert user.username  # never empty

    def test_username_prefix_by_type(self):
        courier = UserFactory(user_type="courier")
        restaurant = UserFactory(user_type="restaurant")
        assert courier.username.startswith("courier_")
        assert restaurant.username.startswith("restaurant_")

    def test_username_collision_gets_suffix(self):
        u1 = UserFactory(email="collide@test.ug", user_type="customer")
        u2 = UserFactory(email="collide@test.ug2", user_type="customer")
        assert u1.username != u2.username
        assert u2.username != "customer_collide"

    def test_phone_validator_rejects_bad_format(self):
        from django.core.exceptions import ValidationError

        user = UserFactory.build(phone="not-a-phone")
        with pytest.raises(ValidationError):
            user.full_clean()

    def test_tokens_returns_jwt_pair(self):
        user = UserFactory()
        tokens = user.tokens()
        assert "refresh" in tokens and "access" in tokens

    def test_manager_requires_email_or_phone(self):
        with pytest.raises(ValueError):
            User.objects.create_user(first_name="A", last_name="B")

    def test_manager_rejects_bad_email(self):
        with pytest.raises(ValueError):
            User.objects.create_user(
                first_name="A", last_name="B", email="bad-email", password="x"
            )


class TestProfiles:
    def test_customer_profile_one_to_one(self):
        profile = CustomerProfileFactory()
        assert profile.user.customer_profile == profile

    def test_restaurant_profile_license_unique(self):
        RestaurantProfileFactory(business_license="LIC-123")
        with pytest.raises(IntegrityError):
            RestaurantProfileFactory(business_license="LIC-123")

    def test_restaurant_profile_location_defaults_to_point(self):
        profile = RestaurantProfileFactory()
        assert profile.location is not None

    def test_courier_defaults(self):
        profile = CourierProfileFactory()
        assert profile.is_available is True
        assert profile.is_approved is True
        assert profile.rating == 0

    def test_staff_profile_links_restaurant(self):
        staff = RestaurantStaffProfileFactory(role="manager")
        assert staff.restaurant.staff.filter(pk=staff.pk).exists()
        assert staff.role == "manager"

    def test_address_requires_user(self):
        address = AddressFactory()
        assert address.user.addresses.filter(pk=address.pk).exists()
        assert Address.objects.count() == 1


class TestOTPCredentials:
    def test_set_and_verify_otp(self):
        record = EmailVerification(email="otp@test.ug", expires_at=None)
        record.set_otp("123456")
        assert record.is_expired() is False
        ok, message = record.verify_otp("123456")
        assert ok is True and message == "Verified"
        assert record.is_verified is True

    def test_wrong_otp_increments_attempts(self):
        record = EmailVerification(email="otp2@test.ug", expires_at=None)
        record.set_otp("111111")
        ok, message = record.verify_otp("999999")
        assert ok is False
        assert record.attempts == 1
        assert "4 attempts remaining" in message

    def test_too_many_attempts_blocked(self):
        record = EmailVerification(email="otp3@test.ug", expires_at=None)
        record.set_otp("111111")
        record.attempts = record.MAX_ATTEMPTS
        record.save()
        ok, message = record.verify_otp("111111")
        assert ok is False and "Too many attempts" in message

    def test_generate_otp_is_6_digits_and_hashed(self):
        record = EmailVerification(email="otp4@test.ug", expires_at=None)
        plain = record.generate_otp()
        assert len(plain) == 6 and plain.isdigit()
        import hashlib

        assert record.otp == hashlib.sha256(plain.encode()).hexdigest()
        # correct OTP verifies against the stored hash
        ok, _ = record.verify_otp(plain)
        assert ok is True
