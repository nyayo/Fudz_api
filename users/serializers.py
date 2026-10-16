from datetime import timedelta

from django.conf import settings
from django.contrib.auth import authenticate
from django.contrib.auth.models import Group
from django.contrib.auth.tokens import PasswordResetTokenGenerator
from django.contrib.gis.geos import Point
from django.db import transaction
from django.contrib.sites.shortcuts import get_current_site
from django.urls import reverse
from django.utils.encoding import DjangoUnicodeDecodeError, force_str, smart_bytes, smart_str
from django.utils.http import urlsafe_base64_decode, urlsafe_base64_encode
from django.utils import timezone
from rest_framework import serializers
from rest_framework.exceptions import AuthenticationFailed
from rest_framework_simplejwt.tokens import RefreshToken, TokenError

from .models import (CourierProfile, CustomerProfile, EmailVerification,
                     NotificationPreference, PhoneVerification,
                     RestaurantProfile, RestaurantStaffProfile, User)
from .services import send_normal_email

REGISTRATION_PROOF_TTL = timezone.timedelta(minutes=30)


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
            record = PhoneVerification.objects.filter(
                phone=data["phone"], is_verified=False
            ).order_by("-created_at", "-pk").first()
        except PhoneVerification.DoesNotExist:
            raise serializers.ValidationError("Invalid OTP or phone number.")
        if record is None:
            raise serializers.ValidationError("Invalid OTP or phone number.")

        if record.is_expired():
            raise serializers.ValidationError("OTP expired.")

        otp_ok, _message = record.verify_otp(data["otp"])
        if not otp_ok:
            raise serializers.ValidationError("Invalid OTP or phone number.")

        user_exists = User.objects.filter(phone=data["phone"]).exists()
        data["user_exists"] = user_exists
        data["requires_registration"] = not user_exists
        data["_record"] = record

        return data

    def create(self, validated_data):
        record = validated_data.pop("_record")
        record.is_verified = True
        record.save()

        user_exists = User.objects.filter(phone=validated_data["phone"]).exists()
        if not user_exists:
            record.expires_at = timezone.now() + REGISTRATION_PROOF_TTL
            record.save(update_fields=["expires_at"])

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
            record = EmailVerification.objects.filter(
                email=data["email"], is_verified=False
            ).order_by("-created_at", "-pk").first()
        except EmailVerification.DoesNotExist:
            raise serializers.ValidationError("Invalid OTP or email.")
        if record is None:
            raise serializers.ValidationError("Invalid OTP or email.")

        if record.is_expired():
            raise serializers.ValidationError("OTP expired.")

        otp_ok, _message = record.verify_otp(data["otp"])
        if not otp_ok:
            raise serializers.ValidationError("Invalid OTP or email.")

        user_exists = User.objects.filter(email=data["email"]).exists()
        data["user_exists"] = user_exists
        data["requires_registration"] = not user_exists
        data["_record"] = record

        return data

    def create(self, validated_data):
        record = validated_data.pop("_record")
        record.is_verified = True
        record.save()

        user_exists = User.objects.filter(email=validated_data["email"]).exists()
        if not user_exists:
            record.expires_at = timezone.now() + REGISTRATION_PROOF_TTL
            record.save(update_fields=["expires_at"])

        return {
            "email": validated_data["email"],
            "verified": True,
            "user_exists": user_exists,
            "requires_registration": not user_exists,
        }


class RegistrationSerializer(serializers.Serializer):
    email = serializers.EmailField(required=False, allow_blank=True)
    first_name = serializers.CharField(max_length=30)
    last_name = serializers.CharField(max_length=30)
    phone = serializers.CharField(max_length=17, required=False, allow_blank=True)
    user_type = serializers.ChoiceField(choices=User.USER_TYPES)
    password = serializers.CharField(min_length=8, write_only=True)
    password2 = serializers.CharField(min_length=8, write_only=True)

    username = serializers.CharField(max_length=100, required=False)
    restaurant_name = serializers.CharField(max_length=100, required=False)
    business_license = serializers.CharField(max_length=100, required=False)
    license_number = serializers.CharField(max_length=50, required=False)
    vehicle_type = serializers.CharField(max_length=50, required=False)
    address = serializers.CharField(required=False)
    latitude = serializers.FloatField(required=False)
    longitude = serializers.FloatField(required=False)

    def validate(self, attrs):
        if attrs["password"] != attrs["password2"]:
            raise serializers.ValidationError("Passwords do not match")

        email = attrs.get("email") or None
        phone = attrs.get("phone") or None

        if email and User.objects.filter(email=email).exists():
            raise serializers.ValidationError(
                "An account with this email already exists. Please login instead."
            )

        if phone and User.objects.filter(phone=phone).exists():
            raise serializers.ValidationError(
                "An account with this phone number already exists. Please login instead."
            )

        verification_time = timezone.now()
        email_verified = bool(
            email
            and EmailVerification.objects.filter(
                email=email,
                is_verified=True,
                expires_at__gt=verification_time,
            ).exists()
        )
        phone_verified = bool(
            phone
            and PhoneVerification.objects.filter(
                phone=phone,
                is_verified=True,
                expires_at__gt=verification_time,
            ).exists()
        )
        if email and not email_verified:
            raise serializers.ValidationError("Email not verified.")
        if not email_verified and not phone_verified:
            raise serializers.ValidationError(
                "A verified email or phone number is required to register."
            )

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

        if user_type == "restaurant":
            latitude = attrs.get("latitude")
            longitude = attrs.get("longitude")
            if latitude is None or longitude is None:
                raise serializers.ValidationError(
                    "Restaurant map location is required; choose the pickup point on the map."
                )
            if not -90 <= latitude <= 90 or not -180 <= longitude <= 180:
                raise serializers.ValidationError(
                    "Restaurant map location is outside valid WGS84 bounds."
                )
            if latitude == 0 and longitude == 0:
                raise serializers.ValidationError(
                    "Select a real restaurant location; (0, 0) is not valid."
                )

        return attrs

    def create(self, validated_data):
        from .tasks import send_templated_email_task

        profile_data = {}
        profile_fields = {
            "customer": [],
            "restaurant": [
                "restaurant_name",
                "business_license",
                "address",
                "latitude",
                "longitude",
            ],
            "courier": ["username", "license_number", "vehicle_type"],
        }

        user_type = validated_data["user_type"]
        for field in profile_fields.get(user_type, []):
            if field in validated_data:
                profile_data[field] = validated_data.pop(field)

        user = User.objects.create_user(
            phone=validated_data.get("phone"),
            first_name=validated_data["first_name"],
            last_name=validated_data["last_name"],
            user_type=validated_data["user_type"],
            email=validated_data.get("email") or None,
            password=validated_data["password"],
            is_verified=True,
        )

        if user_type == "customer":
            CustomerProfile.objects.create(user=user, **profile_data)
        elif user_type == "restaurant":
            latitude = profile_data.pop("latitude")
            longitude = profile_data.pop("longitude")
            profile_data["location"] = Point(longitude, latitude, srid=4326)
            RestaurantProfile.objects.create(user=user, **profile_data)
        elif user_type == "courier":
            CourierProfile.objects.create(user=user, **profile_data)

        if user.email:
            EmailVerification.objects.filter(email=user.email, is_verified=True).update(is_verified=False)
        if user.phone:
            PhoneVerification.objects.filter(phone=user.phone, is_verified=True).update(is_verified=False)

        if user.email:
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


class AdminLoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True, trim_whitespace=False)

    def validate(self, attrs):
        user = authenticate(email=attrs["email"], password=attrs["password"])
        if not user or not user.is_active:
            raise serializers.ValidationError("Invalid admin credentials")
        if not (user.is_staff or user.is_superuser):
            raise serializers.ValidationError("This account does not have admin access")
        attrs["user"] = user
        return attrs


class InvitationActivationSerializer(serializers.Serializer):
    uidb64 = serializers.CharField()
    token = serializers.CharField()
    password = serializers.CharField(min_length=8, write_only=True)
    confirm_password = serializers.CharField(min_length=8, write_only=True)

    def validate(self, attrs):
        if attrs["password"] != attrs["confirm_password"]:
            raise serializers.ValidationError({"confirm_password": "Passwords do not match."})
        try:
            user_id = force_str(urlsafe_base64_decode(attrs["uidb64"]))
            user = User.objects.get(pk=user_id, user_type__in=["restaurant", "restaurant_staff"])
        except (TypeError, ValueError, User.DoesNotExist, DjangoUnicodeDecodeError):
            raise serializers.ValidationError("This invitation link is invalid or has expired.")
        if timezone.now() - user.created_at > timezone.timedelta(minutes=30):
            raise serializers.ValidationError("This invitation link is invalid or has expired.")
        if not PasswordResetTokenGenerator().check_token(user, attrs["token"]):
            raise serializers.ValidationError("This invitation link is invalid or has expired.")
        attrs["user"] = user
        return attrs

    def save(self, **kwargs):
        user = self.validated_data["user"]
        user.set_password(self.validated_data["password"])
        user.is_verified = True
        user.is_active = True
        user.save(update_fields=["password", "is_verified", "is_active", "updated_at"])
        staff_profile = getattr(user, "restaurant_staff_profile", None)
        if staff_profile:
            staff_profile.is_active = True
            staff_profile.save(update_fields=["is_active"])
        return user


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

        # if user_type == "customer" and not attrs.get("phone"):
        #     raise serializers.ValidationError("Phone number is required for customers")
        if user_type == "restaurant" and not all(
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
    full_name = serializers.SerializerMethodField()
    profile = serializers.SerializerMethodField()
    # Contact-completion flags: the apps use these to prompt users who
    # registered with only one contact channel to add the other.
    needs_phone = serializers.SerializerMethodField()
    needs_email = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            "id",
            "username",
            "full_name",
            "first_name",
            "last_name",
            "phone",
            "email",
            "user_type",
            "is_verified",
            "profile",
            "needs_phone",
            "needs_email",
            "is_staff",
            "is_superuser",
        ]
        read_only_fields = ["id", "username", "email", "phone", "user_type", "is_verified", "profile", "needs_phone", "needs_email", "is_staff", "is_superuser"]

    def get_full_name(self, obj):
        return f"{obj.first_name} {obj.last_name}".strip()

    def get_needs_phone(self, obj):
        return not obj.phone

    def get_needs_email(self, obj):
        return not obj.email

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
                    "id": profile.id,
                    "restaurant_id": profile.restaurant_id,
                    "restaurant": profile.restaurant.restaurant_name,
                    "role": profile.role,
                    "is_active": profile.is_active,
                }
        return None


class AdminUserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ["id", "username", "email", "phone", "first_name", "last_name", "user_type", "is_active", "is_verified", "is_staff", "is_superuser", "created_at"]
        read_only_fields = ["id", "username", "email", "phone", "first_name", "last_name", "user_type", "is_staff", "is_superuser", "created_at"]

    def validate_is_active(self, value):
        request = self.context.get("request")
        if not value and self.instance:
            if self.instance.is_superuser:
                raise serializers.ValidationError("Superuser accounts cannot be disabled here.")
            if request and self.instance.pk == request.user.pk:
                raise serializers.ValidationError("You cannot disable your own admin account.")
        return value


class RestaurantStaffSerializer(serializers.ModelSerializer):
    email = serializers.EmailField(write_only=True, required=False)
    password = serializers.CharField(write_only=True, required=False)
    first_name = serializers.CharField(write_only=True, required=False)
    last_name = serializers.CharField(write_only=True, required=False)
    email_display = serializers.EmailField(source="user.email", read_only=True)
    first_name_display = serializers.CharField(source="user.first_name", read_only=True)
    last_name_display = serializers.CharField(source="user.last_name", read_only=True)

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
            "email_display",
            "first_name_display",
            "last_name_display",
        ]
        extra_kwargs = {"restaurant": {"required": False}}

    # def validate(self, attrs):
    #     if User.objects.filter(email=attrs['email']).exists():
    #         raise serializers.ValidationError("Email already registered.")
    #     return attrs

    def create(self, validated_data):
        email = validated_data.pop("email", "")
        password = validated_data.pop("password", None)
        first_name = validated_data.pop("first_name", "")
        last_name = validated_data.pop("last_name", "")
        validated_data.pop("is_active", None)
        role = validated_data["role"]
        user_type = "restaurant_staff"

        user = User.objects.create_user(
            email=email,
            password=None,
            first_name=first_name,
            last_name=last_name,
            user_type=user_type,
            is_active=False,
            is_verified=False,
        )

        auth_group = Group.objects.all()
        print(f"{auth_group} -  role: {role}")
        group = Group.objects.get(name=role)
        user.groups.add(group)

        staff_profile = RestaurantStaffProfile.objects.create(
            user=user, is_active=False, **validated_data
        )
        uidb64 = urlsafe_base64_encode(smart_bytes(user.pk))
        token = PasswordResetTokenGenerator().make_token(user)
        activation_url = (
            f"{settings.FRONTEND_URL.rstrip('/')}/activate-invitation"
            f"?uid={uidb64}&token={token}"
        )
        from .tasks import send_templated_email_task
        transaction.on_commit(lambda: send_templated_email_task.delay(
            user.email,
            "restaurant_invitation",
            {
                "user_name": user.first_name or user.email,
                "restaurant_name": staff_profile.restaurant.restaurant_name,
                "activation_url": activation_url,
                "role": staff_profile.get_role_display(),
            },
        ))
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

    id_token = serializers.CharField()

    def validate(self, attrs):
        from .helpers import Google

        id_token = attrs.get("id_token")
        user = self.context.get("request").user

        # Validate Google token
        user_data = Google.validate(id_token)
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
