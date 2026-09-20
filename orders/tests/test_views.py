"""orders API tests: cart endpoints, order creation, permission matrix."""
import pytest
from rest_framework import status
from rest_framework.test import APIClient

from factories import (
    CartFactory,
    CartItemFactory,
    CustomerProfileFactory,
    MenuItemFactory,
    OrderFactory,
    OrderItemFactory,
    RestaurantProfileFactory,
)
from orders.models import Cart, CartItem, Order

pytestmark = [pytest.mark.django_db, pytest.mark.views]

ORDERS = "/api/v1/orders"


def _client_for(user):
    client = APIClient()
    client.force_authenticate(user)
    return client


class TestCartEndpoints:
    def test_create_cart_authenticated(self, customer_api):
        resp = customer_api.post(f"{ORDERS}/carts/")
        assert resp.status_code == status.HTTP_201_CREATED
        assert Cart.objects.count() == 1

    def test_retrieve_own_cart(self, customer_api, customer_user):
        mine = CartFactory(user=customer_user)
        item = CartItemFactory(cart=mine)
        resp = customer_api.get(f"{ORDERS}/carts/{mine.id}/")
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["id"] == str(mine.id)
        assert len(resp.data["items"]) == 1

    def test_cannot_retrieve_foreign_cart(self, customer_api, db):
        other = CartFactory()
        CartItemFactory(cart=other)
        resp = customer_api.get(f"{ORDERS}/carts/{other.id}/")
        assert resp.status_code == status.HTTP_404_NOT_FOUND

    def test_anon_cart_retrieve_not_leaky(self, anon_api):
        # IsAuthenticatedOrReadOnly allows anon GET, but get_queryset is
        # empty for anonymous users — no data leak. NOTE: anon cart CREATE
        # is also allowed by IsAuthenticatedOrReadOnly (flagged in README).
        cart = CartFactory()
        resp = anon_api.get(f"{ORDERS}/carts/{cart.id}/")
        assert resp.status_code == status.HTTP_404_NOT_FOUND

    def test_add_cart_item(self, customer_api, customer_user):
        cart = CartFactory(user=customer_user)
        menu_item = MenuItemFactory()
        resp = customer_api.post(
            f"{ORDERS}/carts/{cart.id}/items/",
            {"menu_item_id": menu_item.id, "qty": 2},
            format="json",
        )
        assert resp.status_code == status.HTTP_201_CREATED
        assert CartItem.objects.filter(cart=cart).count() == 1

    def test_add_cart_item_unknown_menu_item_400(self, customer_api, customer_user):
        cart = CartFactory(user=customer_user)
        resp = customer_api.post(
            f"{ORDERS}/carts/{cart.id}/items/",
            {"menu_item_id": 123456789, "qty": 1},
            format="json",
        )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST

    def test_cart_items_require_auth(self, anon_api):
        cart = CartFactory()
        resp = anon_api.get(f"{ORDERS}/carts/{cart.id}/items/")
        assert resp.status_code in (status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN)

    def test_update_cart_item_qty(self, customer_api, customer_user):
        cart = CartFactory(user=customer_user)
        item = CartItemFactory(cart=cart, qty=1)
        resp = customer_api.patch(
            f"{ORDERS}/carts/{cart.id}/items/{item.id}/", {"qty": 5}, format="json"
        )
        assert resp.status_code == status.HTTP_200_OK
        item.refresh_from_db()
        assert item.qty == 5

    def test_delete_cart_item(self, customer_api, customer_user):
        cart = CartFactory(user=customer_user)
        item = CartItemFactory(cart=cart)
        resp = customer_api.delete(f"{ORDERS}/carts/{cart.id}/items/{item.id}/")
        assert resp.status_code == status.HTTP_204_NO_CONTENT


class TestOrderPermissions:
    """Permission matrix on OrderViewSet — the core security surface."""

    def test_anonymous_cannot_list(self, anon_api):
        resp = anon_api.get(f"{ORDERS}/orders/")
        assert resp.status_code in (status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN)

    def test_anonymous_cannot_create(self, anon_api):
        resp = anon_api.post(f"{ORDERS}/orders/", {}, format="json")
        assert resp.status_code in (status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN)

    def test_customer_sees_only_own_orders(self, customer_user, db):
        mine = OrderFactory(customer=customer_user.customer_profile)
        OrderFactory()  # other customer
        resp = _client_for(customer_user).get(f"{ORDERS}/orders/")
        assert resp.status_code == 200
        ids = [o["id"] for o in resp.data["results"]]
        assert mine.id in ids and len(ids) == 1

    def test_restaurant_sees_only_own_orders(self, restaurant_user, db):
        mine = OrderFactory(restaurant=restaurant_user.restaurant_profile)
        OrderFactory()
        resp = _client_for(restaurant_user).get(f"{ORDERS}/orders/")
        ids = [o["id"] for o in resp.data["results"]]
        assert ids == [mine.id]

    def test_courier_sees_only_assigned_orders(self, courier_user, db):
        mine = OrderFactory(courier=courier_user.courier_profile)
        OrderFactory()
        resp = _client_for(courier_user).get(f"{ORDERS}/orders/")
        ids = [o["id"] for o in resp.data["results"]]
        assert ids == [mine.id]

    def test_staff_sees_all_orders(self, admin_user, db):
        OrderFactory(), OrderFactory()
        resp = _client_for(admin_user).get(f"{ORDERS}/orders/")
        assert resp.data["count"] == 2

    def test_customer_cannot_read_foreign_order(self, customer_user, db):
        other = OrderFactory()
        resp = _client_for(customer_user).get(f"{ORDERS}/orders/{other.id}/")
        assert resp.status_code == status.HTTP_404_NOT_FOUND


class TestOrderAdminOnlyMutations:
    def test_customer_cannot_patch_order(self, customer_user, db):
        order = OrderFactory(customer=customer_user.customer_profile)
        resp = _client_for(customer_user).patch(
            f"{ORDERS}/orders/{order.id}/", {"status": "delivered"}, format="json"
        )
        assert resp.status_code == status.HTTP_403_FORBIDDEN

    def test_customer_cannot_delete_order(self, customer_user, db):
        order = OrderFactory(customer=customer_user.customer_profile)
        resp = _client_for(customer_user).delete(f"{ORDERS}/orders/{order.id}/")
        assert resp.status_code == status.HTTP_403_FORBIDDEN

    def test_admin_can_patch_status(self, admin_user, db):
        order = OrderFactory()
        resp = _client_for(admin_user).patch(
            f"{ORDERS}/orders/{order.id}/",
            {"status": "accepted", "payment_status": "paid"},
            format="json",
        )
        assert resp.status_code == status.HTTP_200_OK
        order.refresh_from_db()
        assert order.status == "accepted"
        assert order.payment_status == "paid"

    def test_invalid_status_400(self, admin_user, db):
        order = OrderFactory()
        resp = _client_for(admin_user).patch(
            f"{ORDERS}/orders/{order.id}/", {"status": "teleported"}, format="json"
        )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST


class TestOrderCreationFlow:
    def test_create_order_from_cart(self, customer_user, db):
        cart = CartFactory(user=customer_user)
        menu_item = MenuItemFactory()
        CartItemFactory(cart=cart, menu_item=menu_item, qty=1)
        resp = _client_for(customer_user).post(
            f"{ORDERS}/orders/",
            {
                "cart_id": str(cart.id),
                "dropoff_location": {
                    "latitude": 0.3476,
                    "longitude": 32.5825,
                    "address": "Kampala Road",
                },
            },
            format="json",
        )
        assert resp.status_code == status.HTTP_201_CREATED, resp.data
        assert not Cart.objects.filter(pk=cart.pk).exists()
        assert float(resp.data["total_price"]) == float(menu_item.price) * 1

    def test_create_order_empty_cart_400(self, customer_user, db):
        cart = CartFactory(user=customer_user)
        resp = _client_for(customer_user).post(
            f"{ORDERS}/orders/", {"cart_id": str(cart.id)}, format="json"
        )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST

    def test_create_order_without_dropoff_uses_customer_location(self, customer_user, db):
        from django.contrib.gis.geos import Point

        customer_user.customer_profile.current_location = Point(32.5, 0.3, srid=4326)
        customer_user.customer_profile.save()
        cart = CartFactory(user=customer_user)
        CartItemFactory(cart=cart)
        resp = _client_for(customer_user).post(
            f"{ORDERS}/orders/", {"cart_id": str(cart.id)}, format="json"
        )
        assert resp.status_code == status.HTTP_201_CREATED
        assert resp.data["dropoff_location"] is not None


class TestAcceptAction:
    def test_accept_creates_delivery_request(self, restaurant_user, monkeypatch, db):
        from delivery.models import DeliveryRequest

        monkeypatch.setattr("orders.views.auto_assign_courier.delay", lambda *a: None)
        order = OrderFactory(
            restaurant=restaurant_user.restaurant_profile, status="placed"
        )
        resp = _client_for(restaurant_user).post(f"{ORDERS}/orders/{order.id}/accept/")
        assert resp.status_code == 200
        order.refresh_from_db()
        assert order.status == "accepted"
        assert DeliveryRequest.objects.filter(order=order).exists()

    def test_accept_other_restaurants_order_404(self, restaurant_user, db):
        order = OrderFactory()  # belongs to a different restaurant
        resp = _client_for(restaurant_user).post(f"{ORDERS}/orders/{order.id}/accept/")
        assert resp.status_code == status.HTTP_404_NOT_FOUND

    def test_customer_cannot_accept(self, customer_user, monkeypatch, db):
        """Role fix regression: customers must not be able to accept orders."""
        order = OrderFactory(customer=customer_user.customer_profile, status="placed")
        resp = _client_for(customer_user).post(f"{ORDERS}/orders/{order.id}/accept/")
        assert resp.status_code == status.HTTP_403_FORBIDDEN

    def test_accept_non_placed_order_400(self, restaurant_user, monkeypatch, db):
        monkeypatch.setattr("orders.views.auto_assign_courier.delay", lambda *a: None)
        order = OrderFactory(
            restaurant=restaurant_user.restaurant_profile, status="delivered"
        )
        resp = _client_for(restaurant_user).post(f"{ORDERS}/orders/{order.id}/accept/")
        assert resp.status_code == status.HTTP_400_BAD_REQUEST

    def test_accept_not_found_404(self, admin_user, db):
        resp = _client_for(admin_user).post(f"{ORDERS}/orders/999999/accept/")
        assert resp.status_code == status.HTTP_404_NOT_FOUND
