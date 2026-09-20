"""
Root pytest conftest for Fudz_api.

Provides:
- A safe test environment (env vars are required by settings.py, but tests
  must never touch real Firebase / Plunk / TextBee / R2).
- Shared factories: UserFactory and per-profile factories, all Faker-backed.
- Common API client fixtures (anon + authenticated customer/restaurant/courier/staff).
- Celery eager mode so task tests run synchronously in-process.
"""
import base64
import json

import pytest
from django.db import DEFAULT_DB_ALIAS, connections
from django.test.utils import setup_databases
from faker import Faker

from factories import (
    CourierProfileFactory,
    CustomerProfileFactory,
    RestaurantProfileFactory,
    RestaurantStaffProfileFactory,
    UserFactory,
)

fake = Faker()


# ---------------------------------------------------------------------------
# Environment required by settings.py at import time (no secrets, all fake)
# ---------------------------------------------------------------------------
def _ensure_test_env():
    import os

    defaults = {
        "SECRET_KEY": "test-secret-key-not-for-production",
        "DB_NAME": "fudz_delivery_test",
        "DB_USER": "fudz",
        "DB_PASSWORD": "password",
        "DB_HOST": "localhost",
        "DB_PORT": "5433",
        "REDIS_URL": "redis://localhost:6389/1",
        "REDIS_HOST": "localhost",
        "REDIS_PORT": "6389",
        # Firebase Admin SDK: settings initializes an app from a base64 cert
        # at import time. A syntactically valid dummy service-account dict
        # satisfies it; nothing is ever sent to Google from tests.
        "FIREBASE_CREDENTIALS_B64": base64.b64encode(
            json.dumps(
                {
                    "type": "service_account",
                    "project_id": "test-project",
                    "private_key_id": "0000000000000000000000000000000000000000",
                    "private_key": (
                        "-----BEGIN PRIVATE KEY-----\nMIIB\n-----END PRIVATE KEY-----\n"
                    ),
                    "client_email": "test@test-project.iam.gserviceaccount.com",
                    "client_id": "1234567890",
                    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                    "token_uri": "https://oauth2.googleapis.com/token",
                }
            ).encode()
        ).decode(),
        "APNS_CERTIFICATE_PATH": "/tmp/does-not-exist.p8",
        "APNS_TOPIC": "com.fudz.test",
        "WP_PRIVATE_KEY": "-----BEGIN PRIVATE KEY-----\nMIIB\n-----END PRIVATE KEY-----\n",
        "WP_CLAIMS_SUB": "mailto:test@example.com",
        "GOOGLE_CLIENT_ID": "test-google-client-id.apps.googleusercontent.com",
        "GOOGLE_CLIENT_SECRET": "test-google-secret",
        "SOCIAL_AUTH_PASSWORD": "social-test-password-123",
        "EMAIL_HOST": "localhost",
        "EMAIL_HOST_USER": "test",
        "EMAIL_HOST_PASSWORD": "test",
        "DEFAULT_FROM_EMAIL": "no-reply@test.local",
        "EMAIL_PLUNK_API_KEY": "test-plunk-key",
        "TEXTBEE_API_KEY": "test-textbee-key",
        "TEXTBEE_DEVICE_ID": "test-device-id",
        "R2_ACCOUNT_ID": "test",
        "R2_ACCESS_KEY_ID": "test",
        "R2_SECRET_ACCESS_KEY": "test",
        "R2_BUCKET_NAME": "test-bucket",
        "R2_CUSTOM_DOMAIN": "https://test-bucket.example.com",
    }
    for key, value in defaults.items():
        os.environ.setdefault(key, value)


_ensure_test_env()

# Force the same values even if the shell has a real .env loaded for dev
# (decouple reads os.environ first, but be explicit about the test DB).
import os  # noqa: E402

os.environ["DB_NAME"] = "fudz_delivery_test"
os.environ["REDIS_URL"] = "redis://localhost:6389/1"

# ---------------------------------------------------------------------------
# URLs used throughout tests
# ---------------------------------------------------------------------------
USERS_URL = "/api/v1/users"
RESTAURANTS_URL = "/api/v1/restaurants"
ORDERS_URL = "/api/v1/orders"
DELIVERY_URL = "/api/v1/delivery"
REVIEWS_URL = "/api/v1/reviews"
WISHLIST_URL = "/api/v1/wishlists"

# ---------------------------------------------------------------------------
# Celery eager mode: tasks run synchronously, no broker needed.
# ---------------------------------------------------------------------------
@pytest.fixture(scope="session")
def celery_eager_mode():
    from django.conf import settings

    settings.CELERY_TASK_ALWAYS_EAGER = True
    settings.CELERY_TASK_EAGER_PROPAGATES = True
    settings.CELERY_BROKER_URL = "memory://"


@pytest.fixture(autouse=True)
def _celery_always_eager(celery_eager_mode):
    """Apply eager Celery to every test unless a test overrides it."""
    yield


# ---------------------------------------------------------------------------
# Factories as fixtures
# ---------------------------------------------------------------------------
@pytest.fixture
def user_factory():
    return UserFactory


@pytest.fixture
def customer_profile_factory():
    return CustomerProfileFactory


@pytest.fixture
def restaurant_profile_factory():
    return RestaurantProfileFactory


@pytest.fixture
def courier_profile_factory():
    return CourierProfileFactory


@pytest.fixture
def restaurant_staff_profile_factory():
    return RestaurantStaffProfileFactory


# ---------------------------------------------------------------------------
# Ready-made users
# ---------------------------------------------------------------------------
@pytest.fixture
def customer_user(db):
    """A verified customer with a CustomerProfile."""
    return CustomerProfileFactory().user


@pytest.fixture
def restaurant_user(db):
    """A restaurant owner with an approved RestaurantProfile."""
    return RestaurantProfileFactory(is_approved=True).user


@pytest.fixture
def courier_user(db):
    """An approved courier with a CourierProfile."""
    return CourierProfileFactory(is_approved=True).user


@pytest.fixture
def staff_user(db):
    """A restaurant staff member."""
    return RestaurantStaffProfileFactory().user


@pytest.fixture
def admin_user(db):
    from factories import SuperUserFactory

    return SuperUserFactory()


# ---------------------------------------------------------------------------
# API clients
# ---------------------------------------------------------------------------
@pytest.fixture
def anon_api(db):
    from rest_framework.test import APIClient

    return APIClient()


@pytest.fixture
def customer_api(customer_user):
    from rest_framework.test import APIClient

    client = APIClient()
    client.force_authenticate(user=customer_user)
    return client


@pytest.fixture
def restaurant_api(restaurant_user):
    from rest_framework.test import APIClient

    client = APIClient()
    client.force_authenticate(user=restaurant_user)
    return client


@pytest.fixture
def courier_api(courier_user):
    from rest_framework.test import APIClient

    client = APIClient()
    client.force_authenticate(user=courier_user)
    return client


@pytest.fixture
def admin_api(admin_user):
    from rest_framework.test import APIClient

    client = APIClient()
    client.force_authenticate(user=admin_user)
    return client


@pytest.fixture
def jwt_client(db):
    """
    A raw (unauthenticated) client plus a helper to login via JWT and attach
    the resulting access token. Used by auth-flow tests.
    """
    from rest_framework.test import APIClient

    client = APIClient()

    def _login(user):
        tokens = user.tokens()
        client.credentials(HTTP_AUTHORIZATION=f"Bearer {tokens['access']}")
        return tokens

    return client, _login


# ---------------------------------------------------------------------------
# External-network guards: any test that tries a real HTTP call fails loudly.
# ---------------------------------------------------------------------------
@pytest.fixture(autouse=True)
def _block_real_network(monkeypatch):
    """
    Tests must never make real network calls. Any bare `requests.post/get`
    that reaches the wire (instead of being mocked) fails the test with a
    clear message instead of silently hitting the internet.
    """
    import requests

    def _blocked(*args, **kwargs):
        raise AssertionError(
            "Test attempted a real HTTP call via requests. "
            "Mock the external service (Plunk / TextBee / Firebase) instead."
        )

    monkeypatch.setattr(requests.Session, "request", _blocked)


# ---------------------------------------------------------------------------
# Media storage: keep ImageField uploads off the network (R2) and on disk.
# ---------------------------------------------------------------------------
@pytest.fixture(autouse=True)
def _local_media_storage(settings):
    from django.core.files.storage import FileSystemStorage

    settings.STORAGES["default"]["BACKEND"] = (
        "django.core.files.storage.FileSystemStorage"
    )
    settings.MEDIA_ROOT = "/tmp/fudz-test-media"
