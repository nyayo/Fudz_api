from django.urls import path
from rest_framework_nested import routers
from rest_framework_simplejwt.views import TokenRefreshView

from .views import (
    GoogleOauthSignInview,
    LinkGoogleAccountView,
    LogoutApiView,
    NotificationPreferenceView,
    PasswordResetConfirm,
    PasswordResetRequestView,
    RegisterView,
    RequestOTPView,
    RequestPhoneOTPView,
    RestaurantStaffViewSet,
    SetNewPasswordView,
    UserProfileView,
    VerifyOTPView,
    VerifyPhoneOTPView,
    register_device,
    send_test_notification,
    unregister_device,
)

routers = routers.DefaultRouter()
routers.register("auth/staff", RestaurantStaffViewSet, basename="restaurant-staff")

app_name = "users"

urlpatterns = [
    path("auth/request-otp/", RequestOTPView.as_view(), name="request-otp"),
    path("auth/verify-otp/", VerifyOTPView.as_view(), name="verify-otp"),
    path(
        "auth/phone/request-otp/",
        RequestPhoneOTPView.as_view(),
        name="request-phone-otp",
    ),
    path(
        "auth/phone/verify-otp/", VerifyPhoneOTPView.as_view(), name="verify-phone-otp"
    ),
    path("auth/register/", RegisterView.as_view(), name="register"),
    path("auth/google/", GoogleOauthSignInview.as_view(), name="google"),
    path("auth/profile/", UserProfileView.as_view(), name="profile"),
    path("auth/logout/", LogoutApiView.as_view(), name="logout"),
    path(
        "auth/password-reset/",
        PasswordResetRequestView.as_view(),
        name="password-reset",
    ),
    path(
        "auth/password-reset-confirm/<str:uidb64>/<str:token>/",
        PasswordResetConfirm.as_view(),
        name="reset-password-confirm",
    ),
    path(
        "auth/set-new-password/", SetNewPasswordView.as_view(), name="set-new-password"
    ),
    path("auth/device/register/", register_device, name="register_device"),
    path("auth/device/unregister/", unregister_device, name="unregister_device"),
    path("auth/notification/test/", send_test_notification, name="test_notification"),
    path(
        "auth/notification-preferences/",
        NotificationPreferenceView.as_view(),
        name="notification_preferences",
    ),
    path(
        "auth/link-google/",
        LinkGoogleAccountView.as_view(),
        name="link_google",
    ),
    path("auth/token/refresh/", TokenRefreshView.as_view(), name="token_refresh"),
] + routers.urls
