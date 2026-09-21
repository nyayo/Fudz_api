"""orders model tests: constraints, state constants, cart uniqueness."""
import pytest
from django.db import IntegrityError

from factories import (
    CartFactory,
    CartItemFactory,
    OrderFactory,
    OrderItemFactory,
)
from orders.models import (
    Cart,
    CartItem,
    Order,
    OrderItem,
    OrderStatus,
    PaymentStatus,
)

pytestmark = [pytest.mark.django_db, pytest.mark.models]


class TestOrderModel:
    def test_create_defaults(self):
        order = OrderFactory()
        assert order.status == OrderStatus.PLACED
        assert order.payment_status == PaymentStatus.PENDING
        assert order.total_price == 0
        assert order.courier is None

    def test_all_status_choices_valid(self):
        for value, _ in OrderStatus.CHOICES:
            order = OrderFactory(status=value)
            order.refresh_from_db()
            assert order.status == value

    def test_courier_set_null_on_delete(self):
        from factories import CourierProfileFactory

        courier = CourierProfileFactory()
        order = OrderFactory(courier=courier)
        courier.user.delete()
        order.refresh_from_db()
        assert order.courier is None

    def test_order_item_protect_blocks_menu_item_delete(self):
        from django.db.models import ProtectedError
        from factories import MenuItemFactory

        item = MenuItemFactory()
        OrderItemFactory(order=OrderFactory(), menu_item=item, unit_price=item.price)
        with pytest.raises(ProtectedError):
            item.delete()

    def test_order_item_total_price_property(self):
        oi = OrderItemFactory(qty=3, unit_price=2500)
        assert oi.total_price == 7500

    def test_order_item_total_savings(self):
        oi = OrderItemFactory(qty=2, unit_price=1000, discount_amount=500)
        assert oi.total_savings == 1000


class TestCartModel:
    def test_cart_item_unique_per_cart(self):
        cart = CartFactory()
        item = CartItemFactory(cart=cart)
        with pytest.raises(IntegrityError):
            CartItem.objects.create(cart=cart, menu_item=item.menu_item, qty=2)

    def test_adding_same_item_increments_qty(self):
        cart = CartFactory()
        item = CartItemFactory(cart=cart, qty=1)
        item.qty += 2
        item.save()
        assert CartItem.objects.get(cart=cart).qty == 3

    def test_cart_delete_cascades(self):
        cart = CartFactory()
        CartItemFactory(cart=cart)
        cart.delete()
        assert CartItem.objects.count() == 0


class TestStatusConstants:
    def test_completed_statuses(self):
        assert OrderStatus.DELIVERED in OrderStatus.COMPLETED_STATUSES
        assert OrderStatus.CANCELLED in OrderStatus.COMPLETED_STATUSES
        assert OrderStatus.PLACED in OrderStatus.ACTIVE_STATUSES
