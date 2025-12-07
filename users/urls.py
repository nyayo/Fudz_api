from rest_framework_simplejwt.views import TokenRefreshView
from django.urls import path
from rest_framework_nested import routers

from .views import (
    GoogleOauthSignInview,
    PasswordResetConfirm,
    PasswordResetRequestView,
    RequestOTPView,
    SetNewPasswordView,
    VerifyOTPView,
    RegisterView,
    UserProfileView,
    RestaurantStaffViewSet,
    register_device,
    unregister_device,
    send_test_notification,
)

routers = routers.DefaultRouter()
routers.register("auth/staff", RestaurantStaffViewSet, basename="restaurant-staff")

app_name = 'users'

urlpatterns = [
    path("auth/request-otp/", RequestOTPView.as_view(), name="request-otp"),
    path("auth/verify-otp/", VerifyOTPView.as_view(), name="verify-otp"),
    path("auth/register/", RegisterView.as_view(), name="register"),
    path("auth/google/", GoogleOauthSignInview.as_view(), name="google"),
    path('auth/profile/', UserProfileView.as_view(), name='profile'),
    path('auth/password-reset/', PasswordResetRequestView.as_view(), name='password-reset'),
    path('auth/password-reset-confirm/<uidb64>/<token>/', PasswordResetConfirm.as_view(), name='reset-password-confirm'),
    path('auth/set-new-password/', SetNewPasswordView.as_view(), name='set-new-password'),
    
    path('auth/device/register/', register_device, name='register_device'),
    path('auth/device/unregister/', unregister_device, name='unregister_device'),
    path('auth/notification/test/', send_test_notification, name='test_notification'),

    path('auth/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
] + routers.urls