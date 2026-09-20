"""
Test settings: import the real settings then override everything tests must
control — local test database, eager Celery, locmem email, local file storage.
Loaded via DJANGO_SETTINGS_MODULE in pytest.ini.
"""
from Fudz_api.settings import *  # noqa: F401,F403

DEBUG = False
ALLOWED_HOSTS = ["*"]

DATABASES = {
    "default": {
        "ENGINE": "django.contrib.gis.db.backends.postgis",
        "NAME": "fudz_delivery_test",
        "USER": "fudz",
        "PASSWORD": "password",
        "HOST": "localhost",
        "PORT": "5433",
        "TEST": {"NAME": "fudz_delivery_test"},
    }
}

CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.locmem.LocMemCache",
    }
}

CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels.layers.InMemoryChannelLayer",
    }
}

# Celery: run tasks synchronously in-process
CELERY_TASK_ALWAYS_EAGER = True
CELERY_TASK_EAGER_PROPAGATES = True
CELERY_BROKER_URL = "memory://"

# Throttling can interfere with API tests
REST_FRAMEWORK = dict(REST_FRAMEWORK)  # noqa: F405
# keep DEFAULT_THROTTLE_RATES (views declare scoped throttles like 'otp'
# whose rates must resolve); only disable the always-on anon/user throttles.
REST_FRAMEWORK["DEFAULT_THROTTLE_CLASSES"] = []

# Local-disk media instead of Cloudflare R2
STORAGES = {
    "default": {"BACKEND": "django.core.files.storage.FileSystemStorage"},
    "staticfiles": {"BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage"},
}
MEDIA_ROOT = "/tmp/fudz-test-media"

# Password hashing speed: tests use low rounds (matches value used at runtime)
PASSWORD_HASHERS = [
    "django.contrib.auth.hashers.MD5PasswordHasher",
]

# Make emails observable; nothing leaves the machine
EMAIL_BACKEND = "django.core.mail.backends.locmem.EmailBackend"

# Firebase Admin: keep the dummy cert app initialized by base settings;
# messaging.send is always mocked in task tests anyway.

# The base settings module reads secrets from .env via decouple; force
# test-only values where tests rely on predictable values.
GOOGLE_CLIENT_ID = "test-google-client-id.apps.googleusercontent.com"