from datetime import timedelta

from django.conf import settings
from django.contrib.auth import authenticate
from django.contrib.auth.models import Group
from django.contrib.auth.tokens import PasswordResetTokenGenerator
from django.contrib.sites.shortcuts import get_current_site
from django.urls import reverse
from django.utils.encoding import force_str, smart_bytes, smart_str
from django.utils.http import urlsafe_base64_decode, urlsafe_base64_encode
from rest_framework import serializers
from rest_framework.exceptions import AuthenticationFailed
from rest_framework_simplejwt.tokens import RefreshToken, TokenError

from .models import (CourierProfile, CustomerProfile, EmailVerification,
                     NotificationPreference, PhoneVerification,
                     RestaurantProfile, RestaurantStaffProfile, User)
from .services import send_normal_email


class RequestOTPSerializer(serializers.Serializer):
    email = serializers.EmailField()


class RequestPhoneOTPSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=17)

    def validate_phone(self, value):
        import re

        pattern = r"^\+?[1-9]\d{1,14}$"
        if not re.match(pattern, value):
            raise serializers.ValidationError(
                "Phone number must be in international format (e.g., +254712345678)"
            )
        return value


class VerifyPhoneOTPSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=17)
    otp = serializers.CharField(max_length=6, write_only=True)
    user_exists = serializers.BooleanField(read_only=True)
    requires_registration = serializers.BooleanField(read_only=True)

    def validate(self, data):
        try:
            record = PhoneVerification.objects.get(
                phone=data["phone"], otp=data["otp"], is_verified=False
            )
        except PhoneVerification.DoesNotExist:
            raise serializers.ValidationError("Invalid OTP or phone number.")

        if record.is_expired():
            raise serializers.ValidationError("OTP expired.")

        user_exists = User.objects.filter(phone=data["phone"]).exists()
        data["user_exists"] = user_exists
        data["requires_registration"] = not user_exists

        return data

    def create(self, validated_data):
        record = PhoneVerification.objects.get(
            phone=validated_data["phone"], otp=validated_data["otp"]
        )
        record.is_verified = True
        record.save()

        user_exists = User.objects.filter(phone=validated_data["phone"]).exists()

        return {
            "phone": validated_data["phone"],
            "verified": True,
            "user_exists": user_exists,
            "requires_registration": not user_exists,
        }


class VerifyOTPSerializer(serializers.Serializer):
    email = serializers.EmailField()
    otp = serializers.CharField(max_length=6, write_only=True)
    user_exists = serializers.BooleanField(read_only=True)
    requires_registration = serializers.BooleanField(read_only=True)

    def validate(self, data):
        try:
            record = EmailVerification.objects.get(email=data["email"], otp=data["otp"])
        except EmailVerification.DoesNotExist:
            raise serializers.ValidationError("Invalid OTP or email.")

        if record.is_expired():
            raise serializers.ValidationError("OTP expired.")

        user_exists = User.objects.filter(email=data["email"]).exists()
        data["user_exists"] = user_exists
        data["requires_registration"] = not user_exists

        return data

    def create(self, validated_data):
        record = EmailVerification.objects.get(
            email=validated_data["email"], otp=validated_data["otp"]
        )
        record.is_verified = True
        record.save()

        user_exists = User.objects.filter(email=validated_data["email"]).exists()

        return {
            "email": validated_data["email"],
            "verified": True,
            "user_exists": user_exists,
            "requires_registration": not user_exists,
        }


class RegistrationSerializer(serializers.Serializer):
    email = serializers.EmailField()
    first_name = serializers.CharField(max_length=30)
    last_name = serializers.CharField(max_length=30)
    phone = serializers.CharField(max_length=15)
    user_type = serializers.ChoiceField(choices=User.USER_TYPES)
    password = serializers.CharField(min_length=8, write_only=True)
    password2 = serializers.CharField(min_length=8, write_only=True)

    username = serializers.CharField(max_length=100, required=False)
    restaurant_name = serializers.CharField(max_length=100, required=False)
    business_license = serializers.CharField(max_length=100, required=False)
    license_number = serializers.CharField(max_length=50, required=False)
    vehicle_type = serializers.CharField(max_length=50, required=False)
    address = serializers.CharField(required=False)

    def validate(self, attrs):
        if attrs["password"] != attrs["password2"]:
            raise serializers.ValidationError("Passwords do not match")

        if not EmailVerification.objects.filter(
            email=attrs["email"], is_verified=True
        ).exists():
            raise serializers.ValidationError("Email not verified.")

        user_type = attrs["user_type"]
        if user_type == "customer" and not attrs.get("phone"):
            raise serializers.ValidationError("Phone number is required for customers")
        elif user_type == "restaurant" and not all(
            [
                attrs.get("restaurant_name"),
                attrs.get("business_license"),
                attrs.get("address"),
            ]
        ):
            raise serializers.ValidationError(
                "Restaurant name, business license, and address are required for restaurants"
            )
        elif user_type == "courier" and not all(
            [attrs.get("license_number"), attrs.get("vehicle_type")]
        ):
            raise serializers.ValidationError(
                "Full name, license number, and vehicle type are required for couriers"
            )

        return attrs

    def create(self, validated_data):
        from .tasks import send_templated_email_task

        profile_data = {}
        profile_fields = {
            "customer": [],
            "restaurant": ["restaurant_name", "business_license", "address"],
            "courier": ["username", "license_number", "vehicle_type"],
        }

        user_type = validated_data["user_type"]
        for field in profile_fields.get(user_type, []):
            if field in validated_data:
                profile_data[field] = validated_data.pop(field)

        print(f"Validated data: {validated_data}, Profile data: {profile_data}")

        user = User.objects.create_user(
            phone=validated_data["phone"],
            first_name=validated_data["first_name"],
            last_name=validated_data["last_name"],
            user_type=validated_data["user_type"],
            email=validated_data.get("email"),
            password=validated_data["password"],
            is_verified=True,
        )

        if user_type == "customer":
            CustomerProfile.objects.create(user=user, **profile_data)
        elif user_type == "restaurant":
            RestaurantProfile.objects.create(user=user, **profile_data)
        elif user_type == "courier":
            CourierProfile.objects.create(user=user, **profile_data)

        # Send welcome email asynchronously
        send_templated_email_task.delay(
            user.email,
            "welcome_verified",
            {
                "user_name": user.first_name or user.email,
                "username": user.username or user.email,
            },
        )

        return user


class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(required=False)

    def validate(self, attrs):
        email = attrs.get("email")
        password = attrs.get("password")

        if not (email or password):
            raise serializers.ValidationError("Either email or password is required")

        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            raise serializers.ValidationError("User with this email does not exist")

        user = authenticate(email=email, password=password)
        if not user:
            raise serializers.ValidationError("Invalid credentials")

        attrs["user"] = user
        return attrs


class GoogleSignInSerializer(serializers.Serializer):
    access_token = serializers.CharField(min_length=6)
    id_token = serializers.CharField()
    user_type = serializers.ChoiceField(choices=User.USER_TYPES)

    phone = serializers.CharField(max_length=15, required=False)
    restaurant_name = serializers.CharField(max_length=100, required=False)
    business_license = serializers.CharField(max_length=100, required=False)
    address = serializers.CharField(required=False)
    username = serializers.CharField(max_length=100, required=False)
    license_number = serializers.CharField(max_length=50, required=False)
    vehicle_type = serializers.CharField(max_length=50, required=False)

    def validate(self, attrs):
        from .helpers import Google

        access_token = attrs.get("access_token")
        id_token = attrs.get("id_token")
        user_type = attrs.get("user_type")

        user_data = Google.validate(id_token)
        try:
            user_data["sub"]
        except Exception:
            raise serializers.ValidationError(
                "This token has expired or is invalid, please try again"
            )

        if user_data["aud"] != settings.GOOGLE_CLIENT_ID:
            raise AuthenticationFailed("Could not verify user.")

        if user_type == "customer" and not attrs.get("phone"):
            raise serializers.ValidationError("Phone number is required for customers")
        elif user_type == "restaurant" and not all(
            [
                attrs.get("restaurant_name"),
                attrs.get("business_license"),
                attrs.get("address"),
            ]
        ):
            raise serializers.ValidationError(
                "Restaurant name, business license, and address are required for restaurants"
            )
        elif user_type == "courier" and not all(
            [attrs.get("license_number"), attrs.get("vehicle_type")]
        ):
            raise serializers.ValidationError(
                "License number and vehicle type are required for couriers"
            )

        email = user_data["email"]
        first_name = user_data["given_name"]
        last_name = user_data["family_name"]
        provider = "google"
        google_id = user_data["sub"]

        profile_data = {}
        profile_fields = {
            "customer": ["phone"],
            "restaurant": ["restaurant_name", "business_license", "address"],
            "courier": ["username", "license_number", "vehicle_type"],
        }

        for field in profile_fields.get(user_type, []):
            if field in attrs:
                profile_data[field] = attrs[field]

        attrs["_google_data"] = {
            "email": email,
            "first_name": first_name,
            "last_name": last_name,
            "provider": provider,
            "user_type": user_type,
            "profile_data": profile_data,
            "google_id": google_id,
        }

        return attrs

    def validate_access_token(self, access_token):
        return access_token


class PasswordResetRequestSerializer(serializers.Serializer):
    email = serializers.EmailField(max_length=255)

    class Meta:
        fields = ["email"]

    def validate(self, attrs):
        from .tasks import send_templated_email_task

        email = attrs.get("email")
        if User.objects.filter(email=email).exists():
            user = User.objects.get(email=email)
            uidb64 = urlsafe_base64_encode(smart_bytes(user.id))
            token = PasswordResetTokenGenerator().make_token(user)
            request = self.context.get("request")
            current_site = get_current_site(request).domain
            relative_link = reverse(
                "users:reset-password-confirm",
                kwargs={"uidb64": uidb64, "token": token},
            )

            # Generate a reset code (first 6 chars of token for display)
            reset_code = token[:6].upper()

            # Send password reset email asynchronously via Celery
            send_templated_email_task.delay(
                user.email,
                "password_reset",
                {
                    "user_name": user.first_name or user.username,
                    "reset_code": reset_code,
                },
            )

        return super().validate(attrs)


class SetNewPasswordSerializer(serializers.Serializer):
    password = serializers.CharField(max_length=100, min_length=6, write_only=True)
    confirm_password = serializers.CharField(
        max_length=100, min_length=6, write_only=True
    )
    uidb64 = serializers.CharField(min_length=1, write_only=True)
    token = serializers.CharField(min_length=3, write_only=True)

    class Meta:
        fields = ["password", "confirm_password", "uidb64", "token"]

    def validate(self, attrs):
        from .tasks import send_templated_email_task

        try:
            token = attrs.get("token")
            uidb64 = attrs.get("uidb64")
            password = attrs.get("password")
            confirm_password = attrs.get("confirm_password")

            user_id = force_str(urlsafe_base64_decode(uidb64))
            user = User.objects.get(id=user_id)
            if not PasswordResetTokenGenerator().check_token(user, token):
                raise AuthenticationFailed("reset link is invalid or has expired", 401)
            if password != confirm_password:
                raise AuthenticationFailed("passwords do not match")
            user.set_password(password)
            user.save()

            # Send password reset success email asynchronously
            send_templated_email_task.delay(
                user.email,
                "password_reset_success",
                {"user_name": user.first_name or user.username},
            )

            return user
        except Exception as e:
            return AuthenticationFailed("link is invalid or has expired")


class LogoutUserSerializer(serializers.Serializer):
    refresh_token = serializers.CharField()

    default_error_message = {"bad_token": ("Token is expired or invalid")}

    def validate(self, attrs):
        self.token = attrs.get("refresh_token")

        return attrs

    def save(self, **kwargs):
        try:
            token = RefreshToken(self.token)
            token.blacklist()
        except TokenError:
            return self.fail("bad_token")


class UserProfileSerializer(serializers.ModelSerializer):
    profile = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            "id",
            "username",
            "phone",
            "email",
            "user_type",
            "is_verified",
            "profile",
        ]

    def get_profile(self, obj):
        if obj.user_type == "customer":
            profile = getattr(obj, "customer_profile", None)
            if profile:
                return {
                    "order_stats": profile.order_stats,
                    "address": profile.address,
                    "date_of_birth": profile.date_of_birth,
                }
        elif obj.user_type == "restaurant":
            profile = getattr(obj, "restaurant_profile", None)
            if profile:
                return {
                    "id": profile.id,
                    "restaurant_name": profile.restaurant_name,
                    "business_license": profile.business_license,
                    "address": profile.address,
                    "is_approved": profile.is_approved,
                    "is_active": profile.is_active,
                }
        elif obj.user_type == "courier":
            profile = getattr(obj, "courier_profile", None)
            if profile:
                return {
                    "license_number": profile.license_number,
                    "vehicle_type": profile.vehicle_type,
                    "is_approved": profile.is_approved,
                    "is_available": profile.is_available,
                }
        elif obj.user_type == "restaurant_staff":
            profile = getattr(obj, "restaurant_staff_profile", None)
            if profile:
                return {
                    "restaurant": profile.restaurant.restaurant_name,
                    "role": profile.role,
                    "is_verified": profile.is_verified,
                }
        return None


class RestaurantStaffSerializer(serializers.ModelSerializer):
    email = serializers.EmailField(write_only=True, required=False)
    password = serializers.CharField(write_only=True)
    first_name = serializers.CharField(write_only=True, required=False)
    last_name = serializers.CharField(write_only=True, required=False)

    class Meta:
        model = RestaurantStaffProfile
        fields = [
            "id",
            "email",
            "password",
            "first_name",
            "last_name",
            "role",
            "restaurant",
            "is_active",
        ]

    # def validate(self, attrs):
    #     if User.objects.filter(email=attrs['email']).exists():
    #         raise serializers.ValidationError("Email already registered.")
    #     return attrs

    def create(self, validated_data):
        email = validated_data.pop("email", "")
        password = validated_data.pop("password")
        first_name = validated_data.pop("first_name", "")
        last_name = validated_data.pop("last_name", "")
        role = validated_data["role"]
        user_type = "restaurant_staff"

        user = User.objects.create_user(
            email=email,
            password=password,
            first_name=first_name,
            last_name=last_name,
            user_type=user_type,
        )

        auth_group = Group.objects.all()
        print(f"{auth_group} -  role: {role}")
        group = Group.objects.get(name=role)
        user.groups.add(group)

        staff_profile = RestaurantStaffProfile.objects.create(
            user=user, **validated_data
        )
        return staff_profile


class NotificationPreferenceSerializer(serializers.ModelSerializer):
    class Meta:
        model = NotificationPreference
        fields = [
            "id",
            "receive_push",
            "receive_email",
            "promotions_and_offers",
            "new_restaurants",
            "review_reminders",
        ]
        read_only_fields = ["id"]


class LinkGoogleAccountSerializer(serializers.Serializer):
    """Serializer for linking a Google account to an existing user"""

    access_token = serializers.CharField(min_length=6)

    def validate(self, attrs):
        from .helpers import Google

        access_token = attrs.get("access_token")
        user = self.context.get("request").user

        # Validate Google token
        user_data = Google.validate(access_token)
        try:
            user_data["sub"]
        except:
            raise serializers.ValidationError(
                "This token has expired or is invalid, please try again"
            )

        if user_data["aud"] != settings.GOOGLE_CLIENT_ID:
            raise serializers.ValidationError("Could not verify Google account.")

        google_id = user_data["sub"]
        google_email = user_data["email"]

        # Check if this Google account is already linked to another user
        existing_user = (
            User.objects.filter(google_id=google_id).exclude(id=user.id).first()
        )
        if existing_user:
            raise serializers.ValidationError(
                "This Google account is already linked to another user."
            )

        # Check if another user exists with Google as auth provider and same email
        google_auth_user = (
            User.objects.filter(email=google_email, auth_provider="google")
            .exclude(id=user.id)
            .first()
        )
        if google_auth_user:
            raise serializers.ValidationError(
                "A user with this Google email already exists. Please login with Google instead."
            )

        attrs["google_id"] = google_id
        attrs["google_email"] = google_email
        attrs["google_name"] = (
            f"{user_data.get('given_name', '')} {user_data.get('family_name', '')}".strip()
        )

        return attrs

    def save(self):
        user = self.context.get("request").user
        user.google_id = self.validated_data["google_id"]
        user.save(update_fields=["google_id"])
        return user
