"""
Fudz load-test suite (Locust).

Three user classes model realistic food-delivery traffic shapes:
  BrowserUser        ~70%  — cheap reads: restaurant browse/search, menu items
  OrderingUser       ~25%  — full order journey: auth -> browse -> cart -> order -> poll
  EngagementUser     ~5%   — write-heavy: reviews, wishlist add/remove

Configuration (env vars, never hardcode credentials):
  LOADTEST_HOST     target base URL, e.g. http://localhost:8000
  LOADTEST_EMAIL / LOADTEST_PASSWORD   seed customer account (OrderingUser)
  LOADTEST_ANON     set to "1" to run OrderingUser without auth (auth-only path)

Run:
  # local docker-compose
  LOADTEST_HOST=http://localhost:8000 uv run locust -f loadtests/locustfile.py --headless -u 50 -r 5 -t 5m

  # staging
  LOADTEST_HOST=https://staging.fudz.ug uv run locust -f loadtests/locustfile.py --headless -u 20 -r 2 -t 10m

Order-status Celery-bottleneck scenario (see status_fanout.py for instructions):
  locust -f loadtests/locustfile.py -f loadtests/status_fanout.py StatusFanoutUser
"""
import os
import random

from locust import HttpUser, SequentialTaskSet, between, tag, task

HOST_ENV = "LOADTEST_HOST"

# Uganda-shaped payloads -------------------------------------------------------
KAMPALA_COORDS = {"latitude": 0.3476, "longitude": 32.5825, "address": "Kampala Road"}


def env(name, default=None):
    return os.environ.get(name, default)


class BrowserUser(HttpUser):
    """Browsing-heavy: highest volume, all cheap GETs, mostly anonymous."""
    weight = 70
    wait_time = between(1, 4)

    @task(5)
    def browse_restaurants(self):
        self.client.get("/api/v1/restaurants/restaurants/", name="/restaurants [list]")

    @task(3)
    def search_restaurants(self):
        term = random.choice(["kampala", "grill", "chicken", "pizza"])
        self.client.get(
            f"/api/v1/restaurants/restaurants/",
            params={"search": term},
            name="/restaurants [search]",
        )

    @task(4)
    def restaurant_detail(self):
        # sequential-ish id probing like the mobile app does after list
        pk = random.randint(1, 50)
        self.client.get(
            f"/api/v1/restaurants/restaurants/{pk}/", name="/restaurants [detail]"
        )

    @task(3)
    def menu_items(self):
        self.client.get(
            "/api/v1/restaurants/items/",
            params={"is_available": "true"},
            name="/menu-items [list]",
        )

    @task(2)
    def active_promotions(self):
        self.client.get(
            "/api/v1/restaurants/promotions/active/", name="/promotions [active]"
        )

    @task(1)
    def categories(self):
        self.client.get("/api/v1/restaurants/categories/", name="/categories [list]")


class OrderingUser(HttpUser):
    """Full order journey as one weighted flow. Requires a seeded customer
    account (LOADTEST_EMAIL/LOADTEST_PASSWORD) or runs unauthenticated."""
    weight = 25
    wait_time = between(3, 10)
    abstract = False

    def on_start(self):
        self.token = None
        self.cart_id = None
        email = env("LOADTEST_EMAIL")
        password = env("LOADTEST_PASSWORD")
        if email and password:
            resp = self.client.post(
                "/api/v1/users/auth/request-otp/",  # JWT login lives behind OTP flow;
                # for load testing use a pre-minted token instead:
                json={"email": email},
                name="[setup] request-otp",
            )
        # Prefer a pre-minted JWT: LOADTEST_ACCESS_TOKEN
        token = env("LOADTEST_ACCESS_TOKEN")
        if token:
            self.token = token
            self.client.headers["Authorization"] = f"Bearer {token}"

    @task
    def order_journey(self):
        if not self.token:
            # anonymous browsing fallback
            self.client.get("/api/v1/restaurants/restaurants/", name="/restaurants [list]")
            return

        # 1. browse a restaurant
        self.client.get("/api/v1/restaurants/restaurants/", name="/restaurants [list]")
        # 2. menu items
        resp = self.client.get("/api/v1/restaurants/items/", name="/menu-items [list]")
        menu_items = []
        if resp.ok and isinstance(resp.json(), dict):
            menu_items = [r["id"] for r in resp.json().get("results", [])[:5]]
        if not menu_items:
            return

        # 3. create cart
        resp = self.client.post("/api/v1/orders/carts/", name="/carts [create]")
        if resp.status_code != 201:
            return
        self.cart_id = resp.json().get("id")

        # 4. add items
        for _ in range(random.randint(1, 3)):
            self.client.post(
                f"/api/v1/orders/carts/{self.cart_id}/items/",
                json={"menu_item_id": random.choice(menu_items), "qty": random.randint(1, 2)},
                name="/carts/items [add]",
            )

        # 5. place order (fans into Celery: confirmation email + restaurant push)
        resp = self.client.post(
            "/api/v1/orders/orders/",
            json={"cart_id": self.cart_id, "dropoff_location": KAMPALA_COORDS},
            name="/orders [create -> celery fanout]",
        )
        if resp.status_code != 201:
            return
        order_id = resp.json().get("id")

        # 6. poll order status a few times
        for _ in range(random.randint(2, 4)):
            self.client.get(
                f"/api/v1/orders/orders/{order_id}/", name="/orders [poll]"
            )
            self.wait()


class EngagementUser(HttpUser):
    """Write-heavy small weight: wishlist toggling and review reads/writes."""
    weight = 5
    wait_time = between(5, 15)

    def on_start(self):
        token = env("LOADTEST_ACCESS_TOKEN")
        self.token = token
        if token:
            self.client.headers["Authorization"] = f"Bearer {token}"

    @task(3)
    def toggle_wishlist(self):
        if not self.token:
            return
        self.client.get("/api/v1/wishlists/", name="/wishlists [list]")
        menu_item_id = random.randint(1, 200)
        self.client.post(
            "/api/v1/wishlists/add/",
            json={"menu_item_id": menu_item_id},
            name="/wishlists/add [write]",
        )
        self.client.delete(
            f"/api/v1/wishlists/remove/{menu_item_id}/", name="/wishlists/remove [write]"
        )

    @task(1)
    def read_reviews(self):
        restaurant_id = random.randint(1, 50)
        self.client.get(
            f"/api/v1/reviews/",
            params={"restaurant": restaurant_id},
            name="/reviews [list]",
        )


WISHLIST = "/api/v1/wishlists"  # keep reference for readability
