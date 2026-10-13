"""Authorization tests for the dashboard notification inbox."""
import pytest
from rest_framework import status
from rest_framework.test import APIClient

from factories import OrderFactory
from orders.models import Notification


INBOX = "/api/v1/orders/notifications/"


def client_for(user):
    client = APIClient()
    client.force_authenticate(user)
    return client


@pytest.mark.django_db
def test_restaurant_inbox_only_returns_its_orders(restaurant_user):
    own_order = OrderFactory(restaurant=restaurant_user.restaurant_profile)
    foreign_order = OrderFactory()

    response = client_for(restaurant_user).get(INBOX)

    assert response.status_code == status.HTTP_200_OK
    order_ids = {item["order_id"] for item in response.data["results"]}
    assert own_order.id in order_ids
    assert foreign_order.id not in order_ids


@pytest.mark.django_db
def test_restaurant_cannot_mark_foreign_notification_read(restaurant_user):
    foreign_order = OrderFactory()
    notice = Notification.objects.filter(order_id=foreign_order.id).first()
    assert notice is not None

    response = client_for(restaurant_user).post(f"{INBOX}{notice.id}/read/")

    assert response.status_code == status.HTTP_404_NOT_FOUND
    notice.refresh_from_db()
    assert notice.is_read is False


@pytest.mark.django_db
def test_platform_admin_can_see_notifications_across_restaurants(admin_user):
    first = OrderFactory()
    second = OrderFactory()

    response = client_for(admin_user).get(INBOX)

    assert response.status_code == status.HTTP_200_OK
    order_ids = {item["order_id"] for item in response.data["results"]}
    assert first.id in order_ids
    assert second.id in order_ids
