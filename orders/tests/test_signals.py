"""
orders/signals.py tests — verify the right Celery tasks are dispatched with
the right arguments for each status transition, without anything actually
being sent. Channel-layer and email are faked; Celery tasks are stubbed.
"""
import pytest
from django.core import mail
from django.test import override_settings

from factories import OrderFactory
from orders.models import Notification, Order

pytestmark = [pytest.mark.django_db, pytest.mark.signals]


@pytest.fixture
def task_mocks(monkeypatch):
    """Stub every task the signals can dispatch; record their calls."""
    from orders import signals

    calls = {"confirmation": [], "delivered": [], "status": [], "new_order_rest": []}

    monkeypatch.setattr(
        signals.send_order_confirmation_email, "delay", lambda *a: calls["confirmation"].append(a)
    )
    monkeypatch.setattr(
        signals.send_order_delivered_email, "delay", lambda *a: calls["delivered"].append(a)
    )
    monkeypatch.setattr(
        signals.notify_restaurant_order_status, "delay",
        lambda *a: calls["status"].append(a)
    )
    monkeypatch.setattr(
        signals.notify_restaurant_new_order, "delay", lambda *a: calls["new_order_rest"].append(a)
    )
    return calls


@pytest.fixture
def channel_capture(monkeypatch):
    """Capture channel-layer group_send payloads instead of hitting Redis."""
    from orders import signals

    sent = []

    class FakeLayer:
        def group_send(self, group, payload):
            sent.append((group, payload))
            # async_to_sync expects the sync side of a real layer; returning
            # any non-coroutine value is fine at this boundary.

    class FakeLayerModule:
        @staticmethod
        def get_channel_layer():
            return FakeLayer()

    import asgiref.sync as asgiref_sync

    # async_to_sync(channel_layer.group_send)(...) — group_send is sync; the
    # real layers return a coroutine via async wrappers. Simplest correct
    # approach: give group_send an async-compatible signature.
    async def _group_send_async(self, group, payload):
        sent.append((group, payload))

    FakeLayer.group_send = _group_send_async
    monkeypatch.setattr(signals, "get_channel_layer", lambda: FakeLayer())
    return sent


@pytest.fixture
def push_capture(monkeypatch):
    from orders import signals

    calls = []
    monkeypatch.setattr(signals, "send_order_notification", lambda user, title, order: calls.append((user, title, order)))
    return calls


def _make_order():
    return OrderFactory(total_price=10000)


class TestOrderCreatedSignal:
    def test_new_order_dispatches_confirmation_and_restaurant_notify(
        self, task_mocks, channel_capture, push_capture, django_capture_on_commit_callbacks
    ):
        with django_capture_on_commit_callbacks(execute=True):
            order = _make_order()
        assert task_mocks["confirmation"] == [(order.id,)]
        assert task_mocks["new_order_rest"] == [(order.id,)]

    def test_two_notifications_created_on_create(
        self, task_mocks, channel_capture, push_capture
    ):
        _make_order()
        # one from order_notification (admins) + one from customer_order_notification
        assert Notification.objects.count() == 2
        events = set(Notification.objects.values_list("event_type", flat=True))
        assert events == {"new_order"}

    def test_admin_channel_message_sent_on_create(
        self, task_mocks, channel_capture, push_capture
    ):
        _make_order()
        groups = [g for g, _ in channel_capture]
        assert "admin_notifications" in groups

    def test_emails_sent_silently_on_create(
        self, task_mocks, channel_capture, push_capture
    ):
        with override_settings(EMAIL_BACKEND="django.core.mail.backends.locmem.EmailBackend"):
            from factories import SuperUserFactory

            SuperUserFactory(email="admin-oncreate@test.ug")
            _make_order()
            recipients = [to for m in mail.outbox for to in m.to]
            assert "admin-oncreate@test.ug" in recipients
            assert len(recipients) >= 2  # admin + customer


class TestOrderStatusTransitionSignals:
    def test_accepted_dispatches_status_task(self, task_mocks, channel_capture, push_capture, django_capture_on_commit_callbacks):
        order = _make_order()
        task_mocks["status"].clear()
        with django_capture_on_commit_callbacks(execute=True):
            order.status = "accepted"
            order.save()
        assert task_mocks["status"] == [(order.id, "placed", "accepted")]

    def test_ready_dispatches_status_task(self, task_mocks, channel_capture, push_capture, django_capture_on_commit_callbacks):
        order = _make_order()
        with django_capture_on_commit_callbacks(execute=True):
            order.status = "ready"
            order.save()
        assert task_mocks["status"] == [(order.id, "accepted", "ready")]

    def test_picked_up_dispatches_status_task(self, task_mocks, channel_capture, push_capture, django_capture_on_commit_callbacks):
        order = _make_order()
        with django_capture_on_commit_callbacks(execute=True):
            order.status = "picked_up"
            order.save()
        assert task_mocks["status"] == [(order.id, "ready", "picked_up")]

    def test_delivered_dispatches_email_and_status(self, task_mocks, channel_capture, push_capture, django_capture_on_commit_callbacks):
        order = _make_order()
        with django_capture_on_commit_callbacks(execute=True):
            order.status = "delivered"
            order.save()
        assert task_mocks["delivered"] == [(order.id,)]
        assert task_mocks["status"] == [(order.id, "picked_up", "delivered")]

    def test_cancelled_dispatches_nothing(self, task_mocks, channel_capture, push_capture, django_capture_on_commit_callbacks):
        order = _make_order()
        task_mocks["status"].clear()
        task_mocks["delivered"].clear()
        with django_capture_on_commit_callbacks(execute=True):
            order.status = "cancelled"
            order.save()
        assert task_mocks["status"] == []
        assert task_mocks["delivered"] == []

    def test_customer_push_requested_on_each_transition(
        self, task_mocks, channel_capture, push_capture
    ):
        order = _make_order()
        order.status = "delivered"
        order.save()
        assert push_capture, "customer push should be requested"
        user, title, order_arg = push_capture[0]
        assert user == order.customer.user
        assert order_arg == order

    def test_unknown_status_update_creates_no_customer_notification(
        self, task_mocks, channel_capture, push_capture
    ):
        order = _make_order()
        before = Notification.objects.count()
        order.status = "cancelled"
        order.save()
        # customer_order_notification returns early for unknown statuses —
        # only the admin-side notification is created.
        assert Notification.objects.count() == before + 1
