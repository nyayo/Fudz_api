import os
from celery import Celery

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "Fudz_api.settings")

celery = Celery("Fudz_api")
celery.config_from_object("django.conf:settings", namespace="CELERY")
celery.autodiscover_tasks()

