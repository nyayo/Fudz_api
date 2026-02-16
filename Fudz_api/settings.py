import os
from datetime import timedelta
from pathlib import Path

import firebase_admin
from firebase_admin import credentials

BASE_DIR = Path(__file__).resolve().parent.parent


SECRET_KEY = "django-insecure-kg!c-z-901tmp@)+aw^z!q$(=!@m$m2vp3@_dsl93mh%x6%bqf"

DEBUG = True

ALLOWED_HOSTS = []


INSTALLED_APPS = [
    "daphne",
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "django.contrib.gis",
    "drf_spectacular",
    "channels",
    "django_filters",
    "corsheaders",
    "rest_framework",
    "rest_framework_nested",
    "rest_framework_simplejwt",
    "rest_framework_simplejwt.token_blacklist",
    "django_celery_beat",
    "django_celery_results",
    "push_notifications",
    "storages",
    "users",
    "restaurants",
    "orders",
    "delivery",
    "reviews",
    "wishlist",
]

MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "Fudz_api.urls"

ALLOWED_HOSTS = ["localhost", "127.0.0.1"]

CORS_ALLOWED_ORIGINS = [
    "http://localhost:8000",
    "http://127.0.0.1:8000",
]

CORS_ALLOW_ALL_ORIGINS = True


TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [BASE_DIR / "templates"],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "Fudz_api.wsgi.application"


DATABASES = {
    "default": {
        "ENGINE": "django.contrib.gis.db.backends.postgis",
        "NAME": "food_delivery",
        "USER": "neondb_owner",
        "PASSWORD": "npg_5Ok1uzovVgbZ",
        "HOST": "ep-withered-surf-a4thi8j0-pooler.us-east-1.aws.neon.tech",
        "PORT": 5432,
    }
}


AUTH_PASSWORD_VALIDATORS = [
    {
        "NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.MinimumLengthValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.CommonPasswordValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.NumericPasswordValidator",
    },
]


LANGUAGE_CODE = "en-us"

TIME_ZONE = "UTC"

USE_I18N = True

USE_TZ = True


STATIC_URL = "static/"

MEDIA_URL = "/media/"
MEDIA_ROOT = os.path.join(BASE_DIR, "media")


DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

AUTH_USER_MODEL = "users.User"

AUTHENTICATION_BACKENDS = [
    "django.contrib.auth.backends.ModelBackend",
]

FIREBASE_CREDENTIALS_PATH = os.path.join(
    BASE_DIR, "fudz-91926-firebase-adminsdk-fbsvc-d6913fd42a.json"
)
if not firebase_admin._apps:
    cred = credentials.Certificate(FIREBASE_CREDENTIALS_PATH)
    firebase_admin.initialize_app(cred)

PUSH_NOTIFICATIONS_SETTINGS = {
    "APNS_CERTIFICATE": "/path/to/apns/certificate.pem",
    "APNS_TOPIC": "com.yourapp.bundle",
    "WP_PRIVATE_KEY": "your-vapid-private-key",
    "WP_CLAIMS": {"sub": "mailto:your-email@example.com"},
}


SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=15),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=7),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": True,
    "UPDATE_LAST_LOGIN": True,
    "ALGORITHM": "HS256",
    "SIGNING_KEY": SECRET_KEY,
    "AUTH_HEADER_TYPES": ("Bearer",),
    "AUTH_HEADER_NAME": "HTTP_AUTHORIZATION",
}

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": (
        "rest_framework.authentication.SessionAuthentication",
        "rest_framework.authentication.TokenAuthentication",
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ),
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
    "DEFAULT_PERMISSION_CLASSES": [
        "rest_framework.permissions.DjangoModelPermissionsOrAnonReadOnly"
    ],
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "PAGE_SIZE": 20,
    "DEFAULT_THROTTLE_CLASSES": [
        "rest_framework.throttling.AnonRateThrottle",
        "rest_framework.throttling.UserRateThrottle",
    ],
    "DEFAULT_THROTTLE_RATES": {
        "anon": "100/hour",
        "user": "1000/hour",
        "otp": "5/minute",
    },
}

REDIS_URL = "redis://localhost:6379/1"

CELERY_BROKER_URL = REDIS_URL
CELERY_BEAT_SCHEDULER = "django_celery_beat.schedulers:DatabaseScheduler"
CELERY_TIMEZONE = "UTC"
CELERY_ENABLE_UTC = True


ASGI_APPLICATION = "Fudz_api.asgi.application"

CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels_redis.core.RedisChannelLayer",
        "CONFIG": {
            "hosts": [("localhost", 6379)],
        },
    },
}

CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.redis.RedisCache",
        "LOCATION": "redis://localhost:6379/1",
    }
}

SPECTACULAR_SETTINGS = {
    "TITLE": "Fudz Project API",
    "DESCRIPTION": "E-commerce API food delivery project",
    "VERSION": "1.0.0",
    "SERVE_INCLUDE_SCHEMA": False,
    "FIELD_MAPPING": {
        "django.contrib.gis.db.models.PointField": "rest_framework.serializers.JSONField",
    },
    "ENUM_NAME_OVERRIDES": {
        "OrderStatusEnum": "orders.models.OrderStatus.CHOICES",
        "PaymentStatusEnum": "orders.models.PaymentStatus.CHOICES",
        "DeliveryStatusEnum": "delivery.models.DeliveryStatus.CHOICES",
    },
}

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
EMAIL_HOST = "localhost"
EMAIL_HOST_USER = ""
EMAIL_HOST_PASSWORD = ""
DEFAULT_FROM_EMAIL = "info@henryjwtauth.com"
EMAIL_USE_TLS = True
EMAIL_PORT = 2525
EMAIL_PLUNK_API_KEY = "sk_2f4f1a3140079af8c4d647fdfc09945f74b390414d6e1e02"

R2_ACCOUNT_ID = "9f582a41da5edb96b1d7aa0d56dac0b1"
R2_ACCESS_KEY_ID = "5de5dff55055eb06d7462fa81ad724fa"
R2_SECRET_ACCESS_KEY = (
    "c32e2e3aff3afb63a10f4ae0c7619e83f8b05b0f361da856fec91bee6c33f011"
)
R2_BUCKET_NAME = "fudgo"
R2_CUSTOM_DOMAIN = "pub-5937158922ec4cd89a4f0924ecda1ba9.r2.dev"

STORAGES = {
    "default": {
        "BACKEND": "Fudz_api.storage_backends.CloudflareR2Storage",
    },
    "staticfiles": {
        "BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage",
    },
}

GOOGLE_CLIENT_ID = (
    "55727848133-6tp3tfrqc9bkjski9mk0v6309egomf6o.apps.googleusercontent.com"
)
GOOGLE_CLIENT_SECRET = "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"
SOCIAL_AUTH_PASSWORD = "Fudz@12345"
