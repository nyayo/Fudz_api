"""users Celery task tests — Firebase FCM and Plunk email, fully mocked.
No real network calls: firebase_admin.messaging.send / requests.post are patched."""
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import pytest
from push_notifications.models import GCMDevice

from factories import NotificationPreferenceFactory, UserFactory
from users.tasks import (
    send_fcm_notification_admin,
    send_fcm_to_multiple_users,
    send_push_notification_to_user,
)

pytestmark = [pytest.mark.django_db, pytest.mark.tasks]


def _fcm_device(user, token="tok-1", active=True):
    return GCMDevice.objects.create(
        user=user, registration_id=token, active=active
    )


class TestSendFcmNotificationAdmin:
    def test_sends_to_active_gcm_device(self):
        user = UserFactory()
        device = _fcm_device(user, "tok-abc")

        with patch("users.tasks.messaging.send") as mock_send:
            mock_send.return_value = "projects/test/messages/1"
            result = send_fcm_notification_admin(user.id, "Hi", "Body")

        assert result["success_count"] == 1
        assert result["failed_count"] == 0
        assert mock_send.call_count == 1
        # per-device synchronous send: token should appear in the message
        sent_token = mock_send.call_args[0][0].token
        assert sent_token == "tok-abc"

    def test_respects_push_preference_disabled(self):
        user = UserFactory()
        _fcm_device(user)
        NotificationPreferenceFactory(user=user, receive_push=False)

        with patch("users.tasks.messaging.send") as mock_send:
            result = send_fcm_notification_admin(user.id, "Hi", "Body")

        assert result.get("skipped") is True
        mock_send.assert_not_called()

    def test_unregistered_token_marks_device_inactive(self):
        user = UserFactory()
        device = _fcm_device(user, "dead-token")
        from firebase_admin import messaging

        with patch("users.tasks.messaging.send") as mock_send:
            mock_send.side_effect = messaging.UnregisteredError("unregistered")
            result = send_fcm_notification_admin(user.id, "Hi", "Body")

        device.refresh_from_db()
        assert device.active is False
        assert "dead-token" in result["failed_tokens"]

    def test_unknown_user_returns_error(self):
        with patch("users.tasks.messaging.send") as mock_send:
            result = send_fcm_notification_admin(999999, "Hi", "Body")
        assert result == {"error": "User not found"}
        mock_send.assert_not_called()


class TestSendPushNotificationToUser:
    def test_fcm_and_preferences(self):
        user = UserFactory()
        _fcm_device(user, "multi-tok")

        with patch("users.tasks.send_fcm_notification_admin") as mock_fcm:
            mock_fcm.return_value = {"success_count": 1, "failed_count": 0, "failed_tokens": []}
            result = send_push_notification_to_user(
                user.id, "Title", "Body", {"order_id": 7, "type": "order_update"}
            )

        mock_fcm.assert_called_once()
        assert result["fcm"]["success_count"] == 1

    def test_data_values_coerced_to_strings(self):
        user = UserFactory()
        _fcm_device(user)
        with patch("users.tasks.messaging.send") as mock_send:
            send_push_notification_to_user(user.id, "T", "B", {"order_id": 42})
        data = mock_send.call_args[0][0].data
        assert data["order_id"] == "42"


class TestSendFcmToMultipleUsers:
    def test_multicast_batches(self):
        u1, u2 = UserFactory(), UserFactory()
        _fcm_device(u1, "t1")
        _fcm_device(u2, "t2")

        fake_response = SimpleNamespace(
            success_count=2, failure_count=0, responses=[]
        )
        with patch("users.tasks.messaging.send_each_for_multicast") as mock_mc:
            mock_mc.return_value = fake_response
            result = send_fcm_to_multiple_users([u1.id, u2.id], "T", "B")

        assert result["success_count"] == 2
        assert result["total_users"] == 2
        mock_mc.assert_called_once()
        assert set(mock_mc.call_args[0][0].tokens) == {"t1", "t2"}

    def test_no_devices_returns_error(self):
        user = UserFactory()
        result = send_fcm_to_multiple_users([user.id], "T", "B")
        assert result == {"error": "No active devices found"}


class TestPlunkEmailTasks:
    """Email tasks call PlunkEmailService.send_email -> requests.post.
    All HTTP is mocked; the network guard in conftest would fail any real call."""

    def test_send_email_task_success(self, monkeypatch):
        from users.services import PlunkEmailService
        from users.tasks import send_email_task

        monkeypatch.setattr(
            PlunkEmailService, "send_email", staticmethod(lambda data: True)
        )
        result = send_email_task(
            {"to_email": "x@test.ug", "email_subject": "S", "email_body": "B"}
        )
        assert result["success"] is True

    def test_send_email_task_failure_raises(self, monkeypatch):
        from users.services import PlunkEmailService
        from users.tasks import send_email_task

        monkeypatch.setattr(
            PlunkEmailService, "send_email", staticmethod(lambda data: False)
        )
        task = send_email_task
        # eager retries raise MaxRetriesExceededError after exhausting retries
        import celery.exceptions

        with pytest.raises((celery.exceptions.MaxRetriesExceededError, Exception)):
            task.apply(
                args=[{"to_email": "x@test.ug", "email_subject": "S", "email_body": "B"}],
                throw=True,
            )

    def test_send_templated_email_builds_plunk_payload(self, monkeypatch):
        from users.services import PlunkEmailService
        from users.tasks import send_templated_email_task

        captured = {}

        def fake_send_email(data):
            captured.update(data)
            return True

        monkeypatch.setattr(
            PlunkEmailService, "send_email", staticmethod(fake_send_email)
        )
        result = send_templated_email_task(
            "user@test.ug", "email_verification", {"user_name": "U", "verification_code": "123456"}
        )
        assert result["success"] is True
        assert captured["to_email"] == "user@test.ug"
        assert captured["email_type"] == "html"

    def test_send_order_confirmation_email_queues_templated_send(self, monkeypatch):
        from factories import OrderFactory, OrderItemFactory
        from users import tasks as users_tasks

        order = OrderFactory(total_price=20000)
        OrderItemFactory(order=order, qty=2)

        calls = []
        monkeypatch.setattr(
            users_tasks.send_templated_email_task, "delay", lambda *a: calls.append(a)
        )
        result = users_tasks.send_order_confirmation_email(order.id)
        assert result["success"] is True
        assert calls, "templated email should be queued"
        to_email, template, kwargs = calls[0]
        assert to_email == order.customer.user.email
        assert template == "order_confirmation"
        assert kwargs["order_id"] == str(order.id)
