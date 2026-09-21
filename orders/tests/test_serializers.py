"""orders serializer tests: cart pricing with promotions, create-order flow."""
from datetime import timedelta
from decimal import Decimal

import pytest
from django.utils import timezone

from factories import (
    CartFactory,
    CartItemFactory,
    MenuItemFactory,
    PromotionFactory,
)
from orders.models import Cart
from orders.serializers import (
    AddCartItemSerializer,
    CartSerializer,
    CreateOrderSerializer,
)

pytestmark = [pytest.mark.django_db, pytest.mark.serializers]


class TestCartPricing:
    def test_total_price_no_promotions(self):
        cart = CartFactory()
        item = CartItemFactory(cart=cart, qty=2, menu_item__price=Decimal("5000.00"))
        data = CartSerializer(cart).data
        assert data["total_price"] == 10000.0
        assert data["restaurant_id"] == item.menu_item.restaurant_id

    def test_total_price_with_active_promotion(self):
        cart = CartFactory()
        menu_item = MenuItemFactory(price=Decimal("10000.00"))
        promo = PromotionFactory(
            restaurant=menu_item.restaurant, discount=20.0,
            start_date=timezone.now() - timedelta(hours=1),
            end_date=timezone.now() + timedelta(hours=1),
        )
        menu_item.promotions.add(promo)
        CartItemFactory(cart=cart, menu_item=menu_item, qty=1)
        data = CartSerializer(cart).data
        assert data["total_price"] == 8000.0

    def test_expired_promotion_does_not_discount(self):
        cart = CartFactory()
        menu_item = MenuItemFactory(price=Decimal("10000.00"))
        promo = PromotionFactory(
            restaurant=menu_item.restaurant, discount=50.0,
            start_date=timezone.now() - timedelta(days=2),
            end_date=timezone.now() - timedelta(days=1),
        )
        menu_item.promotions.add(promo)
        CartItemFactory(cart=cart, menu_item=menu_item, qty=1)
        assert CartSerializer(cart).data["total_price"] == 10000.0

    def test_empty_cart(self):
        cart = CartFactory()
        data = CartSerializer(cart).data
        assert data["total_price"] == 0.0
        assert data["restaurant_id"] is None


class TestAddCartItemSerializer:
    def _ctx(self, cart):
        return {"cart_id": cart.id}

    def test_valid_menu_item(self):
        cart = CartFactory()
        menu_item = MenuItemFactory()
        s = AddCartItemSerializer(
            data={"menu_item_id": menu_item.id, "qty": 2}, context=self._ctx(cart)
        )
        assert s.is_valid(), s.errors

    def test_unknown_menu_item_rejected(self):
        cart = CartFactory()
        s = AddCartItemSerializer(
            data={"menu_item_id": 987654321, "qty": 1}, context=self._ctx(cart)
        )
        assert not s.is_valid()
        assert "No available menu item" in str(s.errors)

    def test_save_accumulates_qty(self):
        cart = CartFactory()
        menu_item = MenuItemFactory()
        s = AddCartItemSerializer(
            data={"menu_item_id": menu_item.id, "qty": 2}, context=self._ctx(cart)
        )
        assert s.is_valid()
        s.save()
        s2 = AddCartItemSerializer(
            data={"menu_item_id": menu_item.id, "qty": 1}, context=self._ctx(cart)
        )
        assert s2.is_valid()
        instance = s2.save()
        assert instance.qty == 3


class TestCreateOrderSerializer:
    def _payload(self, cart):
        return {
            "cart_id": str(cart.id),
            "dropoff_location": {
                "latitude": 0.3476,
                "longitude": 32.5825,
                "address": "Plot 12, Kampala Road",
            },
        }

    def _ctx(self, user):
        return {"user_id": user.id}

    def test_cart_id_validation_empty_cart(self):
        user = CartFactory().user
        cart = CartFactory(user=user)
        s = CreateOrderSerializer(
            data=self._payload(cart), context=self._ctx(user)
        )
        assert not s.is_valid()
        assert "empty" in str(s.errors).lower()

    def test_unknown_cart(self):
        user = CartFactory().user
        s = CreateOrderSerializer(
            data={"cart_id": "00000000-0000-0000-0000-000000000000"},
            context=self._ctx(user),
        )
        assert not s.is_valid()
        assert "No active cart" in str(s.errors)

    def test_save_creates_order_and_deletes_cart(self):
        from orders.models import Order, OrderItem

        user = CartFactory().user
        cart = CartFactory(user=user)
        menu_item = MenuItemFactory(price=Decimal("8000.00"))
        CartItemFactory(cart=cart, menu_item=menu_item, qty=2)

        s = CreateOrderSerializer(
            data=self._payload(cart), context=self._ctx(user)
        )
        assert s.is_valid(), s.errors
        order = s.save()

        assert Order.objects.filter(pk=order.pk).exists()
        assert order.customer.user == user
        assert order.restaurant_id == menu_item.restaurant_id
        assert order.total_price == Decimal("16000.00")
        assert OrderItem.objects.filter(order=order).count() == 1
        assert not Cart.objects.filter(pk=cart.pk).exists(), "cart cleared after order"

    def test_save_applies_promotion_pricing(self):
        from orders.models import OrderItem

        user = CartFactory().user
        cart = CartFactory(user=user)
        menu_item = MenuItemFactory(price=Decimal("10000.00"))
        promo = PromotionFactory(
            restaurant=menu_item.restaurant, discount=25.0,
            start_date=timezone.now() - timedelta(hours=1),
            end_date=timezone.now() + timedelta(hours=1),
        )
        menu_item.promotions.add(promo)
        CartItemFactory(cart=cart, menu_item=menu_item, qty=1)

        s = CreateOrderSerializer(
            data=self._payload(cart), context=self._ctx(user)
        )
        assert s.is_valid(), s.errors
        order = s.save()
        oi = OrderItem.objects.get(order=order)
        assert oi.unit_price == Decimal("7500.00")
        assert order.total_price == Decimal("7500.00")
