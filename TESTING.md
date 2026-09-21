# Testing & Load Testing

## Test suite

Stack: pytest, pytest-django, pytest-cov, factory_boy, Faker.

### Layout

```
conftest.py                    # root: env setup, clients, network guard, celery eager
factories.py                   # shared Faker-backed factories for every app's models
Fudz_api/test_settings.py      # test overrides (local PG, locmem email, eager celery)
users/tests/                   # test_models / test_serializers / test_views / test_tasks
restaurants/tests/             # test_models / test_views
orders/tests/                  # test_models / test_serializers / test_views / test_signals
delivery/tests/                # test_views
reviews/tests/                 # test_views (+ model constraints)
wishlist/tests/                # test_views (+ model constraints)
```

Every external boundary is mocked — the suite makes **zero real network calls**:
- Firebase `messaging.send` / `send_each_for_multicast` → patched per test
- Plunk HTTP (`users.services.PlunkEmailService`) → patched / `requests` blocked
- TextBee SMS → patched (dev fallback)
- Cloudflare R2 → replaced with local FileSystemStorage
- Redis (channels + cache) → InMemoryChannelLayer / LocMemCache
- Celery → `CELERY_TASK_ALWAYS_EAGER`

A guard in `conftest.py` (`_block_real_network`) fails any test that tries a
real `requests` call, so a forgotten mock is loud, not silent.

### Bugs fixed alongside the suite

The suite initially pinned several app bugs as expected behavior; they are now
fixed in app code and the tests assert the corrected behavior (regression
tests in place):

- `users/serializers.py` RegistrationSerializer.validate — bare `not phone`
  NameError + `attrs["phone"]` KeyError: **registration was broken for every
  payload**. Now uses `attrs.get(...)` and only enforces email/phone checks
  when the field is present.
- `VerifyOTPSerializer` / `VerifyPhoneOTPSerializer` — wrong-OTP acceptance
  (`verify_otp` returns a truthy tuple). **Security bug**: any 6-digit string
  verified an email/phone. Now checks the tuple's bool.
- `orders.views.OrderViewSet.accept` — no role check: any authenticated user
  could accept an order. Now restaurant-owner-or-staff only, plus a
  status guard (only `placed` orders can be accepted).
- `delivery.views.DeliveryRequestViewSet` — no `permission_classes`
  (anonymous users could list every delivery). Now `IsAuthenticated`.
- `users.permissions.IsManagerOrReadOnly` — restaurant owners were denied
  menu-item/category writes unless in a literal "Manager" Django group.
  Now accepts `user_type == "restaurant"` too.
- Routed previously-dead endpoints:
  `restaurants/items/on-promotion/`, `items/{id}/add-promotion/`,
  `items/{id}/remove-promotion/`, `delivery/earnings/`,
  `delivery/earnings/summary/` (the earnings views also had a broken
  `user.courierprofile` reverse accessor — fixed to `courier_profile`,
  with non-courier guards).

### Run it

Requires the dev PostGIS + Redis containers (`docker compose -f docker-compose.dev.yml up -d db redis`).
Tests use database `fudz_delivery_test` on `localhost:5433`.

```bash
# venv (project currently uses .venv2 — see note below)
source .venv2/bin/activate

pytest                                  # whole suite (~25s)
pytest users/tests/test_views.py -v     # one module
pytest -m views                         # by marker: models/serializers/views/tasks/signals

pytest --cov=users --cov=restaurants --cov=orders --cov=delivery --cov=reviews \
       --cov=wishlist --cov-report=term-missing
```

NOTE: the old `.venv` in the repo root is owned by root and points to a
removed interpreter — it must be deleted with `sudo rm -rf .venv` once; until
then a parallel `.venv2` holds the working environment. Recreate the canonical
one with `uv venv && uv pip install -r requirements.txt`.

### CI (fits the existing docker-compose setup)

```yaml
# .github/workflows/tests.yml — jobs run inside a container built from the
# project Dockerfile (same as docker-compose.yml services), against service
# containers:
services:
  db:
    image: imresamu/postgis:16-3.4
    env:
      POSTGRES_USER: fudz
      POSTGRES_PASSWORD: password
      POSTGRES_DB: fudz_delivery_test
    ports: ["5433:5432"]
steps:
  - run: uv sync
  - run: uv pip install pytest pytest-django pytest-cov factory-boy Faker
  - run: pytest --cov --cov-report=xml -q
```

No Redis/Celery services needed in CI — the suite runs tasks eagerly in-process.

## Load testing (Locust)

Chosen over k6 because: the codebase is Python, the fan-out behavior we want
to exercise (Celery task enqueue rate) is easiest to reason about alongside
Django code, and Locust's weighted user classes map 1:1 to the journey mix.

### Traffic shape (weights in `loadtests/locustfile.py`)

| Class           | Weight | Behavior |
|-----------------|--------|----------|
| `BrowserUser`   | 70%    | anonymous GETs: restaurant list/search/detail, menu items, active promotions, categories |
| `OrderingUser`  | 25%    | auth → browse → create cart → add items → place order (Celery fanout) → poll status |
| `EngagementUser`| 5%     | wishlist add/remove, review reads |

`status_fanout.py` adds `StatusFanoutUser`, a dedicated scenario hammering
order-status transitions (`PATCH /orders/{id}/`) — each one triggers
`orders/signals.py`: Plunk email task + FCM push task + admin `send_mail` +
channels-redis group_send. Watch Redis queue depth while it runs (see below).

### Run

```bash
cd loadtests

# local docker-compose
LOADTEST_HOST=http://localhost:8000 \
locust -f locustfile.py --headless -u 50 -r 5 -t 5m

# staging (never production without rate limiting at the edge!)
LOADTEST_HOST=https://staging.fudz.ug \
LOADTEST_ACCESS_TOKEN=<seed-user-jwt> \
locust -f locustfile.py --headless -u 20 -r 2 -t 10m

# Celery-bottleneck scenario
LOADTEST_HOST=http://localhost:8000 LOADTEST_ACCESS_TOKEN=<admin-jwt> \
locust -f locustfile.py -f status_fanout.py StatusFanoutUser --headless -u 10 -r 1 -t 5m
```

Credentials come only from env vars (`LOADTEST_EMAIL`, `LOADTEST_PASSWORD`,
`LOADTEST_ACCESS_TOKEN`) — never commit them. Seed a throwaway customer +
staff account in the target environment and mint a JWT for the run.

### Monitoring queue depth during the status-fanout run

```bash
watch -n 10 "redis-cli -p 6389 llen celery"        # queue depth over time
# or Flower at :5555; or celery worker logs for retry storms
```

## Load-test report template (fill in after each run)

```
Run metadata
  Target:            [url]
  Date/duration:     [iso] / [N min]
  Concurrency:       [u users, r spawn rate]
  Commit:            [git sha]

Per-endpoint latency (ms)             median      p95      p99      err%
  GET  /restaurants/ [list]        [ ..... ]  [ ..... ] [ ..... ] [ ..... ]
  GET  /restaurants/ [search]      [ ..... ]  [ ..... ] [ ..... ] [ ..... ]
  GET  /restaurants/{id}/          [ ..... ]  [ ..... ] [ ..... ] [ ..... ]
  GET  /menu-items/ [list]         [ ..... ]  [ ..... ] [ ..... ] [ ..... ]
  GET  /promotions/ [active]       [ ..... ]  [ ..... ] [ ..... ] [ ..... ]
  POST /carts/ [create]            [ ..... ]  [ ..... ] [ ..... ] [ ..... ]
  POST /carts/{id}/items/ [add]    [ ..... ]  [ ..... ] [ ..... ] [ ..... ]
  POST /orders/ [create->celery]   [ ..... ]  [ ..... ] [ ..... ] [ ..... ]
  GET  /orders/{id}/ [poll]        [ ..... ]  [ ..... ] [ ..... ] [ ..... ]
  PATCH /orders/{id}/ [transition] [ ..... ]  [ ..... ] [ ..... ] [ ..... ]
  POST /wishlists/add/             [ ..... ]  [ ..... ] [ ..... ] [ ..... ]
  GET  /reviews/                   [ ..... ]  [ ..... ] [ ..... ] [ ..... ]

Celery / Redis
  Queue depth @ start:              [n]
  Queue depth peak:                 [n]  (timestamp)
  Queue depth @ end:                [n]
  Longest task wait (Flower):       [s]
  Failed tasks:                     [n]  (types: [...])
  Worker CPU / RAM peak:            [% / MB]

Notes / regressions observed:
  [...]
```

**Backlog signal to watch**: if queue depth climbs monotonically during the
status-fanout scenario and doesn't drain within ~2× the run duration after
traffic stops, the per-device synchronous FCM loop in
`users.tasks.send_fcm_notification_admin` (one `messaging.send` round-trip
per GCM device, inside the same task, no batching) is the bottleneck. Fix
shape: switch to `send_each_for_multicast` (already exists in
`send_fcm_to_multiple_users`) and/or split email vs push into separate queues
with independent workers.

## Starting concurrency recommendation (Uganda, early scale)

Assume a launch city (Kampala) with ~5–20k MAU: peak load is lunch (12–14h)
and dinner (18–20h). At early scale a realistic peak is **~50–150 concurrent
sessions**, of which the large majority are cheap reads.

- Daytime baseline: `10–20 users` (Locust), mostly BrowserUser
- Mealtime peak drill: `50 users` (u=50, r=5)
- Pre-launch soak: `30 users` for 30+ min watching p95 and memory
- Status-fanout stress: `10 StatusFanoutUser` + `30 BrowserUser` together —
  this is the combination most likely to expose the Celery bottleneck

Don't scale beyond ~200 simulated users until per-endpoint p95 < 500 ms for
reads and < 1 s for order creation at the mealtime-peak level.
