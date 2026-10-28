"""WebSocket delivery/location authorization regressions."""

import asyncio
import pytest
from channels.routing import URLRouter
from channels.testing import WebsocketCommunicator
from django.contrib.auth.models import AnonymousUser

from delivery.models import DeliveryRequest
from delivery.routing import websocket_urlpatterns
from factories import CustomerProfileFactory, OrderFactory

pytestmark = pytest.mark.django_db(transaction=True)


def communicator(user, path):
    async def app(scope, receive, send):
        scope["user"] = user
        await URLRouter(websocket_urlpatterns)(scope, receive, send)

    return WebsocketCommunicator(app, path)


def test_anonymous_delivery_tracking_rejected():
    async def check():
        socket = communicator(AnonymousUser(), "/ws/delivery/track/1/")
        accepted, code = await socket.connect()
        assert not accepted and code == 4403
        await socket.disconnect()

    asyncio.run(check())


def test_foreign_customer_cannot_track_delivery():
    order = OrderFactory()
    delivery = DeliveryRequest.objects.create(order=order)
    foreign = CustomerProfileFactory().user

    async def check():
        socket = communicator(foreign, f"/ws/delivery/track/{delivery.pk}/")
        accepted, code = await socket.connect()
        assert not accepted and code == 4403
        await socket.disconnect()

    asyncio.run(check())


def test_order_customer_can_track_delivery():
    order = OrderFactory()
    delivery = DeliveryRequest.objects.create(order=order)
    user = order.customer.user

    async def check():
        socket = communicator(user, f"/ws/delivery/track/{delivery.pk}/")
        accepted, _ = await socket.connect()
        assert accepted
        await socket.receive_json_from()
        await socket.disconnect()

    asyncio.run(check())


def test_customer_cannot_write_another_customers_location():
    user, other = CustomerProfileFactory().user, CustomerProfileFactory().user

    async def check():
        socket = communicator(user, f"/ws/customer/{other.pk}/")
        accepted, code = await socket.connect()
        assert not accepted and code == 4403
        await socket.disconnect()

    asyncio.run(check())


def test_customer_can_update_own_location_with_zero_coordinate():
    customer = CustomerProfileFactory()

    async def check():
        socket = communicator(customer.user, f"/ws/customer/{customer.user_id}/")
        accepted, _ = await socket.connect()
        assert accepted
        await socket.receive_json_from()
        await socket.send_json_to({"lat": 0, "lng": 32})
        response = await socket.receive_json_from()
        assert response["type"] == "location_received"
        await socket.disconnect()

    asyncio.run(check())
    customer.refresh_from_db()
    assert customer.current_location.y == 0 and customer.current_location.x == 32
