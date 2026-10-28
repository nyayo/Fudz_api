"""Caller-held, expiring proofs of OTP verification for registration."""

from django.core import signing
from django.utils import timezone
from rest_framework.exceptions import ValidationError

SALT = "users.registration-proof.v1"
MAX_AGE = 30 * 60


def issue_registration_proof(record, channel):
    return signing.dumps(
        {"channel": channel, "id": record.pk, "otp": record.otp}, salt=SALT
    )


def read_registration_proof(token, *, lock=False):
    from .models import EmailVerification, PhoneVerification

    try:
        data = signing.loads(token, salt=SALT, max_age=MAX_AGE)
        channel = data["channel"]
        model = {"email": EmailVerification, "phone": PhoneVerification}[channel]
        queryset = model.objects.select_for_update() if lock else model.objects
        record = queryset.get(
            pk=data["id"],
            otp=data["otp"],
            is_verified=True,
            expires_at__gt=timezone.now(),
        )
    except (
        signing.BadSignature,
        KeyError,
        TypeError,
        ValueError,
        EmailVerification.DoesNotExist,
        PhoneVerification.DoesNotExist,
    ):
        raise ValidationError(
            {
                "registration_token": "Verification is invalid or expired. Verify your contact again."
            }
        )
    return channel, record
