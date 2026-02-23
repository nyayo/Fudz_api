#!/bin/sh
uv run python manage.py migrate --noinput
uv run python manage.py collectstatic --noinput
uv run gunicorn --bind 0.0.0.0:8000 --workers 3 Fudz_api.wsgi:application
