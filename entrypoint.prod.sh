#!/bin/sh
uv run python manage.py migrate --noinput
uv run python manage.py collectstatic --noinput
uv run gunicorn --bind 0.0.0.0:8000 \
  --workers $((2 * N + 1)) \
  --worker-class gthread \
  --threads 2 \
  --timeout 30 \
  --graceful-timeout 30 \
  --max-requests 1000 \
  --max-requests-jitter 100 \
  --keep-alive 5 \
  Fudz_api.wsgi:application

