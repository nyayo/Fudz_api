"""Cookie refresh sessions for the dashboard; mobile JWT endpoints stay intact."""

from django.conf import settings
from rest_framework.exceptions import PermissionDenied
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.serializers import TokenRefreshSerializer
from rest_framework_simplejwt.tokens import RefreshToken, TokenError

from .models import User
from push_notifications.models import WebPushDevice


def require_browser_origin(request):
    # These endpoints use ambient cookies. Exact Origin checking is mandatory
    # on every operation, including logout and session establishment (login CSRF).
    origin = request.headers.get("Origin")
    if not origin or origin not in settings.BROWSER_SESSION_ORIGINS:
        raise PermissionDenied("Dashboard origin is not allowed.")


def session_response(data=None, *, refresh=None):
    response = Response(data or {})
    response["Cache-Control"] = "no-store"
    if refresh is not None:
        response.set_cookie(
            settings.BROWSER_REFRESH_COOKIE,
            str(refresh),
            httponly=True,
            secure=True,
            samesite="None",
            path=settings.BROWSER_REFRESH_COOKIE_PATH,
            max_age=int(settings.SIMPLE_JWT["REFRESH_TOKEN_LIFETIME"].total_seconds()),
        )
    return response


class BrowserSessionView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        require_browser_origin(request)
        try:
            refresh = RefreshToken(request.data.get("refresh", ""))
            if str(refresh["user_id"]) != str(request.user.pk):
                raise PermissionDenied("Session does not belong to this account.")
            # The refresh token returned by login is no longer reusable after
            # it has been exchanged for the browser-only cookie credential.
            refresh.blacklist()
            replacement = RefreshToken.for_user(request.user)
        except TokenError:
            return Response({"detail": "Invalid refresh token."}, status=401)
        return session_response(refresh=replacement)


class BrowserRefreshView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    def post(self, request):
        require_browser_origin(request)
        raw = request.COOKIES.get(settings.BROWSER_REFRESH_COOKIE, "")
        try:
            token = RefreshToken(raw)
            if not User.objects.filter(pk=token["user_id"], is_active=True).exists():
                raise TokenError("Inactive user")
            serializer = TokenRefreshSerializer(data={"refresh": raw})
            serializer.is_valid(raise_exception=True)
        except TokenError:
            return Response({"detail": "Session expired."}, status=401)
        data = serializer.validated_data
        return session_response(
            {"access": data["access"]}, refresh=data.get("refresh", raw)
        )


class BrowserLogoutView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    def post(self, request):
        require_browser_origin(request)
        raw = request.COOKIES.get(settings.BROWSER_REFRESH_COOKIE)
        if raw:
            try:
                token = RefreshToken(raw)
                endpoint = request.data.get("registration_id")
                if isinstance(endpoint, str) and endpoint:
                    WebPushDevice.objects.filter(
                        user_id=token["user_id"], registration_id=endpoint
                    ).update(active=False)
                token.blacklist()
            except TokenError:
                pass  # An expired/revoked cookie must still be removed.
        response = session_response()
        response.delete_cookie(
            settings.BROWSER_REFRESH_COOKIE,
            path=settings.BROWSER_REFRESH_COOKIE_PATH,
            samesite="None",
        )
        return response
