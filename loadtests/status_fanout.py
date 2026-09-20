"""
StatusFanoutUser — targeted load on the order-status-change path.

Why this scenario matters for Fudz specifically:
Every order status transition fires orders/signals.py, which fans out into
Celery tasks: send_order_confirmation_email / send_order_delivered_email
(Plunk HTTP), notify_restaurant_order_status (FCM), send_push_notification_to_user
(synchronous per-device FCM calls in a loop inside users/tasks.py), plus
send_mail to every staff admin and a channels-redis group_send. At load this
is the known bottleneck shape: one slow FCM round-trip per device, per
transition, inside the worker.

What to measure while this runs:
  1. Redis queue depth over time:
     redis-cli -h localhost -p 6389 llen celery   (repeat every ~10s)
     or: redis-cli -h localhost -p 6389 info | grep -E 'lag|queue'
  2. Flower: http://localhost:5555 for worker queue/concurrency
  3. p95 latency of PATCH /orders/{id}/ (the transition itself) and of
     POST /delivery/deliveries/{id}/update-status/ (courier path)

Run (as an admin — status changes are IsAdminUser on OrderViewSet PATCH,
or via the delivery update-status endpoint as the assigned courier):
  LOADTEST_HOST=http://localhost:8000 \
  LOADTEST_ACCESS_TOKEN=<admin-jwt> \
  locust -f loadtests/locustfile.py -f loadtests/status_fanout.py \
         StatusFanoutUser --headless -u 10 -r 1 -t 5m
"""
import os
import random

from locust import HttpUser, between, task

from locustfile import KAMPALA_COORDS  # noqa: F401  (run from loadtests/ cwd)


class StatusFanoutUser(HttpUser):
    """Drives status transitions: placed -> accepted -> ready -> picked_up -> delivered."""

    wait_time = between(2, 5)
    fixed_count = 0

    def on_start(self):
        token = os.environ.get("LOADTEST_ACCESS_TOKEN")
        if not token:
            raise SystemExit(
                "StatusFanoutUser needs LOADTEST_ACCESS_TOKEN (staff JWT) — "
                "status PATCH is IsAdminUser."
            )
        self.client.headers["Authorization"] = f"Bearer {token}"

    @task
    def advance_order(self):
        # pick any active order created earlier by OrderingUser
        resp = self.client.get(
            "/api/v1/orders/orders/",
            params={"status": "placed"},
            name="/orders [scan placed]",
        )
        if not resp.ok:
            return
        results = resp.json().get("results", [])
        if not results:
            return
        order = random.choice(results)

        next_status = random.choice(["accepted", "ready", "picked_up", "delivered"])
        self.client.patch(
            f"/api/v1/orders/orders/{order['id']}/",
            json={"status": next_status},
            name=f"/orders [status -> {next_status} -> celery fanout]",
        )
