from rest_framework import throttling
from rest_framework.throttling import AnonRateThrottle


class OTPRateThrottle(AnonRateThrottle):
    """
    Rate limit for OTP requests to prevent brute force attacks.
    Limits to 5 requests per minute per IP.
    """
    scope = "otp"

    def get_cache_key(self, request, view):
        if request.user and request.user.is_authenticated:
            ident = request.user.pk
        else:
            ident = self.get_ident(request)

        return self.cache_format % {
            "scope": self.scope,
            "ident": ident,
        }


class PasswordResetThrottle(throttling.AnonRateThrottle):
    rate = '3/hour'
    scope = 'password_reset'


class GoogleAuthThrottle(throttling.AnonRateThrottle):
    rate = '10/minute'
    scope = 'google_auth'
