import os
from datetime import timedelta
from pathlib import Path
from decouple import config, Csv

import firebase_admin
from firebase_admin import credentials

BASE_DIR = Path(__file__).resolve().parent.parent


SECRET_KEY = config("SECRET_KEY")

DEBUG = config("DEBUG", default=True, cast=bool)

DJANGO_APPS = [
    "daphne",
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "django.contrib.gis",
]

THIRD_PARTY_APPS = [
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
]

LOCAL_APPS = [
    "users",
    "restaurants",
    "orders",
    "delivery",
    "reviews",
    "wishlist",
]

INSTALLED_APPS = DJANGO_APPS + THIRD_PARTY_APPS + LOCAL_APPS



MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "whitenoise.middleware.WhiteNoiseMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "Fudz_api.urls"

ALLOWED_HOSTS = config("ALLOWED_HOSTS", default="*", cast=Csv())

CSRF_TRUSTED_ORIGINS = config("CSRF_TRUSTED_ORIGINS", default="", cast=Csv())

CORS_ALLOW_ALL_ORIGINS = config("CORS_ALLOW_ALL_ORIGINS", default=True, cast=bool)


STATICFILES_STORAGE = "whitenoise.storage.CompressedManifestStaticFilesStorage"


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

# DATABASES = {
#     "default": {
#         "ENGINE": "django.contrib.gis.db.backends.postgis",
#         "NAME": "food_delivery",
#         "USER": "neondb_owner",
#         "PASSWORD": "npg_5Ok1uzovVgbZ",
#         "HOST": "ep-withered-surf-a4thi8j0-pooler.us-east-1.aws.neon.tech",
#         "PORT": 5432,
#     }
# }

DATABASES = {
    "default": {
        "ENGINE": config("DB_ENGINE", default="django.contrib.gis.db.backends.postgis"),
        "NAME": config("DB_NAME"),
        "USER": config("DB_USER"),
        "PASSWORD": config("DB_PASSWORD"),
        "HOST": config("DB_HOST"),
        "PORT": config("DB_PORT", default=5432),
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


STATIC_URL = "/static/"
STATIC_ROOT = os.path.join(BASE_DIR, "staticfiles")

MEDIA_URL = "/media/"
MEDIA_ROOT = os.path.join(BASE_DIR, "media")


DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

AUTH_USER_MODEL = "users.User"

AUTHENTICATION_BACKENDS = [
    "django.contrib.auth.backends.ModelBackend",
]

FIREBASE_CREDENTIALS_PATH = os.path.join(
    BASE_DIR, "delivery-1d642-firebase-adminsdk-fbsvc-cb2bd40215.json"
)
if not firebase_admin._apps:
    cred = credentials.Certificate(FIREBASE_CREDENTIALS_PATH)
    firebase_admin.initialize_app(cred)

PUSH_NOTIFICATIONS_SETTINGS = {
    "APNS_CERTIFICATE": config("APNS_CERTIFICATE_PATH"),
    "APNS_TOPIC": config("APNS_TOPIC"),
    "WP_PRIVATE_KEY": config("WP_PRIVATE_KEY"),
    "WP_CLAIMS": {"sub": config("WP_CLAIMS_SUB")},
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
        "password_reset": "3/hour",
        "google_auth": "10/minute",
    },
    "EXCEPTION_HANDLER": "Fudz_api.exceptions.custom_exception_handler",
}

CELERY_BROKER_URL = config("REDIS_URL")
CELERY_BEAT_SCHEDULER = "django_celery_beat.schedulers:DatabaseScheduler"
CELERY_TIMEZONE = "UTC"
CELERY_ENABLE_UTC = True


ASGI_APPLICATION = "Fudz_api.asgi.application"

CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels_redis.core.RedisChannelLayer",
        "CONFIG": {
            "hosts": [(config("REDIS_HOST"), config("REDIS_PORT"))],
        },
    },
}

CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.redis.RedisCache",
        "LOCATION": config("REDIS_URL"),
    }
}

SPECTACULAR_SETTINGS = {
    "TITLE": "Fudz Project API",
    "DESCRIPTION": "E-commerce API food delivery",
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
EMAIL_HOST = config("EMAIL_HOST", default="smtp.mailtrap.io")
EMAIL_HOST_USER = config("EMAIL_HOST_USER")
EMAIL_HOST_PASSWORD = config("EMAIL_HOST_PASSWORD")
DEFAULT_FROM_EMAIL = config("DEFAULT_FROM_EMAIL")
EMAIL_USE_TLS = config("EMAIL_USE_TLS", default=True)
EMAIL_PORT = config("EMAIL_PORT", default=2525)
EMAIL_PLUNK_API_KEY = config("EMAIL_PLUNK_API_KEY")

TEXTBEE_API_KEY = config("TEXTBEE_API_KEY")
TEXTBEE_DEVICE_ID = config("TEXTBEE_DEVICE_ID")


R2_ACCOUNT_ID = config("R2_ACCOUNT_ID")
R2_ACCESS_KEY_ID = config("R2_ACCESS_KEY_ID")
R2_SECRET_ACCESS_KEY = (
    config("R2_SECRET_ACCESS_KEY")
)
R2_BUCKET_NAME = config("R2_BUCKET_NAME")
R2_CUSTOM_DOMAIN = config("R2_CUSTOM_DOMAIN")

STORAGES = {
    "default": {
        "BACKEND": "Fudz_api.storage_backends.CloudflareR2Storage",
    },
    "staticfiles": {
        "BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage",
    },
}

GOOGLE_CLIENT_ID = (
    config("GOOGLE_CLIENT_ID")
)
GOOGLE_CLIENT_SECRET = config("GOOGLE_CLIENT_SECRET")
SOCIAL_AUTH_PASSWORD = config("SOCIAL_AUTH_PASSWORD")

LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '{levelname} {asctime} {module} {process:d} {thread:d} {message}',
            'style': '{',
        },
        'simple': {
            'format': '{levelname} {asctime} {module} {message}',
            'style': '{',
        },
    },
    'handlers': {
        'console': {
            'level': 'INFO',
            'class': 'logging.StreamHandler',
            'formatter': 'simple',
        },
    },
    'loggers': {
        'django': {
            'handlers': ['console'],
            'level': 'INFO',
            'propagate': True,
        },
        'users': {
            'handlers': ['console'],
            'level': 'INFO',
            'propagate': False,
        },
        'orders': {
            'handlers': ['console'],
            'level': 'INFO',
            'propagate': False,
        },
        'delivery': {
            'handlers': ['console'],
            'level': 'INFO',
            'propagate': False,
        },
        'celery': {
            'handlers': ['console'],
            'level': 'INFO',
            'propagate': False,
        },
    },
}
