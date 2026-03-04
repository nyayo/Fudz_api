import logging

from django.contrib.auth.tokens import PasswordResetTokenGenerator
from django.utils import timezone
from django.utils.encoding import DjangoUnicodeDecodeError, smart_str
from django.utils.http import urlsafe_base64_decode
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import extend_schema, inline_serializer
from push_notifications.models import APNSDevice, GCMDevice, WebPushDevice
from rest_framework import generics
from rest_framework import serializers as drf_serializers
from rest_framework import status, viewsets
from rest_framework.decorators import api_view, permission_classes
from rest_framework.generics import GenericAPIView
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from users.permissions import IsRestaurantOwner
from users.throttling import OTPRateThrottle

from .email_templates import get_email_template
from .helpers import get_tokens_for_user, register_social_user
from .models import (
    EmailVerification,
    NotificationPreference,
    PhoneVerification,
    RestaurantStaffProfile,
    User,
)
from .serializers import (
    GoogleSignInSerializer,
    LinkGoogleAccountSerializer,
    LogoutUserSerializer,
    NotificationPreferenceSerializer,
    PasswordResetRequestSerializer,
    RegistrationSerializer,
    RequestOTPSerializer,
    RequestPhoneOTPSerializer,
    RestaurantStaffSerializer,
    SetNewPasswordSerializer,
    UserProfileSerializer,
    VerifyOTPSerializer,
    VerifyPhoneOTPSerializer,
)
from .services import OTPService, PlunkEmailService, SMSService
from .tasks import send_push_notification_to_user, send_sms_otp_task, send_templated_email_task

logger = logging.getLogger(__name__)


class RequestOTPView(GenericAPIView):
    serializer_class = RequestOTPSerializer
    permission_classes = [AllowAny]
    throttle_classes = [OTPRateThrottle]

    def post(self, request):
        from .services import send_normal_email

        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        email = serializer.validated_data.get("email")

        try:
            otp_obj, created = EmailVerification.objects.get_or_create(
                email=email,
                is_verified=False,
                defaults={
                    "expires_at": timezone.now() + timezone.timedelta(minutes=10)
                },
            )

            if not created:
                otp_obj.is_verified = False
                otp_obj.expires_at = timezone.now() + timezone.timedelta(minutes=10)

            otp_obj.generate_otp()

            verification_code = otp_obj.otp

            # Send verification email asynchronously via Celery
            send_templated_email_task.delay(
                email,
                "email_verification",
                {"user_name": email, "verification_code": verification_code},
            )

            OTPService.send_otp(email, otp_obj.otp)

            return Response(
                {"message": "OTP sent successfully to your email"},
                status=status.HTTP_200_OK,
            )

        except Exception as e:
            return Response(
                {"message": "Failed to generate OTP", "error": str(e)},
                status=status.HTTP_400_BAD_REQUEST,
            )


class RequestPhoneOTPView(GenericAPIView):
    """Request OTP for phone number authentication"""
    serializer_class = RequestPhoneOTPSerializer
    permission_classes = [AllowAny]
    throttle_classes = [OTPRateThrottle]

    def post(self, request):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        phone = serializer.validated_data.get("phone")

        try:
            otp_obj, created = PhoneVerification.objects.get_or_create(
                phone=phone,
                is_verified=False,
                defaults={
                    "expires_at": timezone.now() + timezone.timedelta(minutes=10)
                },
            )

            if not created:
                otp_obj.is_verified = False
                otp_obj.expires_at = timezone.now() + timezone.timedelta(minutes=10)

            otp_obj.generate_otp()

            # Send OTP via SMS asynchronously using Celery
            send_sms_otp_task.delay(phone, otp_obj.otp)

            return Response(
                {"message": "OTP sent successfully to your phone number"},
                status=status.HTTP_200_OK,
            )

        except Exception as e:
            logger.error(f"Failed to send phone OTP: {str(e)}")
            return Response(
                {"message": "Failed to generate OTP", "error": str(e)},
                status=status.HTTP_400_BAD_REQUEST,
            )


class VerifyPhoneOTPView(generics.CreateAPIView):
    """Verify phone OTP and authenticate or prompt registration"""
    serializer_class = VerifyPhoneOTPSerializer
    permission_classes = [AllowAny]
    throttle_classes = [OTPRateThrottle]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        result = serializer.save()

        if result["user_exists"]:
            user = User.objects.get(phone=result["phone"])
            tokens = get_tokens_for_user(user)
            return Response(
                {
                    "message": "Login successful",
                    "verified": True,
                    "user_exists": True,
                    "requires_registration": False,
                    "user": UserProfileSerializer(user).data,
                    "tokens": tokens,
                    "can_link_google": not bool(user.google_id),
                },
                status=status.HTTP_200_OK,
            )

        return Response(
            {
                "message": "Phone verified. Please complete registration.",
                "verified": True,
                "user_exists": False,
                "requires_registration": True,
                "phone": result["phone"],
            },
            status=status.HTTP_200_OK,
        )


class VerifyOTPView(generics.CreateAPIView):
    serializer_class = VerifyOTPSerializer
    permission_classes = [AllowAny]
    throttle_classes = [OTPRateThrottle]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        result = serializer.save()

        if result["user_exists"]:
            user = User.objects.get(email=result["email"])
            tokens = get_tokens_for_user(user)
            return Response(
                {
                    "message": "Login successful",
                    "verified": True,
                    "user_exists": True,
                    "requires_registration": False,
                    "user": UserProfileSerializer(user).data,
                    "tokens": tokens,
                    "can_link_google": not bool(user.google_id),
                },
                status=status.HTTP_200_OK,
            )

        return Response(
            {
                "message": "Email verified. Please complete registration.",
                "verified": True,
                "user_exists": False,
                "requires_registration": True,
                "email": result["email"],
            },
            status=status.HTTP_200_OK,
        )


from django.db import IntegrityError

class RegisterView(generics.CreateAPIView):
    serializer_class = RegistrationSerializer
    permission_classes = [AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            user = serializer.save()
        except IntegrityError as e:
            error_str = str(e).lower()
            if "email" in error_str:
                return Response(
                    {"error": "An account with this email already exists. Please login instead."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            elif "phone" in error_str:
                return Response(
                    {"error": "An account with this phone number already exists. Please login instead."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            return Response(
                {"error": "An account with these details already exists."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        except Exception as e:
            return Response(
                {"error": str(e)},
                status=status.HTTP_400_BAD_REQUEST,
            )
        tokens = get_tokens_for_user(user)
        return Response(
            {
                "message": "Registration successful.",
                "user": UserProfileSerializer(user).data,
                "tokens": tokens,
                "can_link_google": True,
            },
            status=status.HTTP_201_CREATED,
        )


class GoogleOauthSignInview(generics.GenericAPIView):
    serializer_class = GoogleSignInSerializer
    queryset = User.objects.none()
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = self.serializer_class(data=request.data)
        serializer.is_valid(raise_exception=True)

        google_data = serializer.validated_data["_google_data"]

        response = register_social_user(
            provider=google_data["provider"],
            email=google_data["email"],
            first_name=google_data["first_name"],
            last_name=google_data["last_name"],
            user_type=google_data["user_type"],
            profile_data=google_data["profile_data"],
            google_id=google_data["google_id"],
        )

        return Response(response.data, status=response.status_code)


class LogoutApiView(GenericAPIView):
    serializer_class = LogoutUserSerializer
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = self.serializer_class(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(status=status.HTTP_204_NO_CONTENT)


class PasswordResetRequestView(GenericAPIView):
    serializer_class = PasswordResetRequestSerializer
    queryset = User.objects.none()
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = self.serializer_class(
            data=request.data, context={"request": request}
        )
        serializer.is_valid(raise_exception=True)
        return Response(
            {"message": "we have sent you a link to reset your password"},
            status=status.HTTP_200_OK,
        )
        # return Response({'message':'user with that email does not exist'}, status=status.HTTP_400_BAD_REQUEST)


class PasswordResetConfirm(GenericAPIView):
    queryset = User.objects.none()
    serializer_class = SetNewPasswordSerializer

    @extend_schema(
        responses={
            200: inline_serializer(
                name="PasswordResetConfirmResponse",
                fields={
                    "success": drf_serializers.BooleanField(),
                    "message": drf_serializers.CharField(),
                    "uidb64": drf_serializers.CharField(),
                    "token": drf_serializers.CharField(),
                },
            )
        }
    )
    def get(self, request, uidb64, token):
        try:
            user_id = smart_str(urlsafe_base64_decode(uidb64))
            user = User.objects.get(id=user_id)

            if not PasswordResetTokenGenerator().check_token(user, token):
                return Response(
                    {"message": "token is invalid or has expired"},
                    status=status.HTTP_401_UNAUTHORIZED,
                )
            return Response(
                {
                    "success": True,
                    "message": "credentials is valid",
                    "uidb64": uidb64,
                    "token": token,
                },
                status=status.HTTP_200_OK,
            )

        except DjangoUnicodeDecodeError as identifier:
            return Response(
                {"message": "token is invalid or has expired"},
                status=status.HTTP_401_UNAUTHORIZED,
            )


class SetNewPasswordView(APIView):
    serializer_class = SetNewPasswordSerializer
    queryset = User.objects.none()
    permission_classes = [AllowAny]

    def patch(self, request):
        serializer = self.serializer_class(data=request.data)
        serializer.is_valid(raise_exception=True)
        return Response(
            {"success": True, "message": "password reset is succesful"},
            status=status.HTTP_200_OK,
        )


class UserProfileView(GenericAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = UserProfileSerializer

    def get(self, request):
        serializer = UserProfileSerializer(request.user)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def put(self, request):
        user = request.user
        serializer = UserProfileSerializer(user, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()

            if user.user_type == "restaurant" and "profile" in request.data:
                profile_data = request.data.get("profile", {})
                restaurant_profile = user.restaurant_profile
                for key, value in profile_data.items():
                    setattr(restaurant_profile, key, value)
                restaurant_profile.save()

            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class RestaurantStaffViewSet(viewsets.ModelViewSet):
    queryset = RestaurantStaffProfile.objects.all()
    serializer_class = RestaurantStaffSerializer
    permission_classes = [IsAuthenticated, IsRestaurantOwner]

    def get_queryset(self):
        restaurant = self.request.user.restaurant_profile
        return RestaurantStaffProfile.objects.filter(restaurant=restaurant)

    def perform_create(self, serializer):
        restaurant = self.request.user.restaurant_profile
        serializer.save(restaurant=restaurant)


@extend_schema(
    request=inline_serializer(
        name="RegisterDeviceRequest",
        fields={
            "registration_id": drf_serializers.CharField(),
            "type": drf_serializers.ChoiceField(choices=["android", "ios", "web"]),
            "name": drf_serializers.CharField(required=False),
        },
    ),
    responses={
        200: inline_serializer(
            name="RegisterDeviceResponse",
            fields={
                "success": drf_serializers.BooleanField(),
                "created": drf_serializers.BooleanField(),
                "device_id": drf_serializers.IntegerField(),
            },
        )
    },
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def register_device(request):
    """
    Register a device for push notifications

    POST data:
    {
        "registration_id": "device-token",
        "type": "android|ios|web",
        "name": "optional-device-name"
    }
    """
    device_type = request.data.get("type")
    registration_id = request.data.get("registration_id")
    name = request.data.get("name", "")

    if not registration_id or not device_type:
        return Response({"error": "registration_id and type are required"}, status=400)

    try:
        if device_type == "android":
            device, created = GCMDevice.objects.get_or_create(
                registration_id=registration_id,
                defaults={"user": request.user, "name": name},
            )
        elif device_type == "ios":
            device, created = APNSDevice.objects.get_or_create(
                registration_id=registration_id,
                defaults={"user": request.user, "name": name},
            )
        elif device_type == "web":
            device, created = WebPushDevice.objects.get_or_create(
                registration_id=registration_id,
                defaults={"user": request.user, "name": name},
            )
        else:
            return Response({"error": "Invalid device type"}, status=400)

        if not created:
            device.user = request.user
            device.active = True
            device.save()

        return Response(
            {"success": True, "created": created, "device_id": device.device_id}
        )

    except Exception as e:
        return Response({"error": str(e)}, status=500)


@extend_schema(
    request=inline_serializer(
        name="SendTestNotificationRequest",
        fields={
            "title": drf_serializers.CharField(required=False),
            "message": drf_serializers.CharField(required=False),
            "data": drf_serializers.JSONField(required=False),
        },
    ),
    responses={
        200: inline_serializer(
            name="SendTestNotificationResponse",
            fields={
                "success": drf_serializers.BooleanField(),
                "message": drf_serializers.CharField(),
            },
        )
    },
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def send_test_notification(request):
    """
    Send a test notification to the current user
    """
    title = request.data.get("title", "Test Notification")
    message = request.data.get("message", "This is a test message")
    data = request.data.get("data", {})
    send_push_notification_to_user.delay(request.user.id, title, message, data)

    return Response({"success": True, "message": "Notification queued"})


@extend_schema(
    request=inline_serializer(
        name="UnregisterDeviceRequest",
        fields={
            "registration_id": drf_serializers.CharField(),
        },
    ),
    responses={
        200: inline_serializer(
            name="UnregisterDeviceResponse",
            fields={
                "success": drf_serializers.BooleanField(),
                "message": drf_serializers.CharField(),
            },
        )
    },
)
@api_view(["DELETE"])
@permission_classes([IsAuthenticated])
def unregister_device(request):
    """
    Unregister a device

    POST data:
    {
        "registration_id": "device-token"
    }
    """
    registration_id = request.data.get("registration_id")

    if not registration_id:
        return Response({"error": "registration_id required"}, status=400)

    for model in [GCMDevice, APNSDevice, WebPushDevice]:
        try:
            device = model.objects.get(
                registration_id=registration_id, user=request.user
            )
            device.active = False
            device.save()
            return Response({"success": True, "message": "Device unregistered"})
        except model.DoesNotExist:
            continue

    return Response({"error": "Device not found"}, status=404)


class NotificationPreferenceView(generics.RetrieveUpdateAPIView):
    """
    GET: Retrieve current user's notification preferences
    PUT/PATCH: Update notification preferences
    """

    serializer_class = NotificationPreferenceSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        obj, _ = NotificationPreference.objects.get_or_create(user=self.request.user)
        return obj


class LinkGoogleAccountView(generics.GenericAPIView):
    """
    Link a Google account to an existing user account.
    
    This allows users who registered with phone/email to also login via Google.
    POST: Link Google account using Google access token
    DELETE: Unlink Google account
    """
    serializer_class = LinkGoogleAccountSerializer
    permission_classes = [IsAuthenticated]

    @extend_schema(
        request=LinkGoogleAccountSerializer,
        responses={
            200: inline_serializer(
                name="LinkGoogleAccountResponse",
                fields={
                    "message": drf_serializers.CharField(),
                    "google_linked": drf_serializers.BooleanField(),
                },
            )
        },
    )
    def post(self, request):
        """Link a Google account to the current user"""
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        
        return Response(
            {
                "message": "Google account linked successfully",
                "google_linked": True,
            },
            status=status.HTTP_200_OK,
        )

    @extend_schema(
        responses={
            200: inline_serializer(
                name="UnlinkGoogleAccountResponse",
                fields={
                    "message": drf_serializers.CharField(),
                    "google_linked": drf_serializers.BooleanField(),
                },
            )
        },
    )
    def delete(self, request):
        """Unlink Google account from the current user"""
        user = request.user
        
        if not user.google_id:
            return Response(
                {"message": "No Google account linked"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        
        # Prevent unlinking if Google is the only auth method
        if user.auth_provider == 'google' and not user.has_usable_password():
            return Response(
                {"message": "Cannot unlink Google account as it's your only login method. Set a password first."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        
        user.google_id = None
        user.save(update_fields=['google_id'])
        
        return Response(
            {
                "message": "Google account unlinked successfully",
                "google_linked": False,
            },
            status=status.HTTP_200_OK,
        )

    def get(self, request):
        """Check Google account linking status"""
        user = request.user
        return Response(
            {
                "google_linked": bool(user.google_id),
                "can_unlink": user.google_id and (user.auth_provider != 'google' or user.has_usable_password()),
            },
            status=status.HTTP_200_OK,
        )
