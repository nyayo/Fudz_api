"""delivery API tests: courier dispatch, status transitions, earnings."""
import pytest
from rest_framework import status
from rest_framework.test import APIClient

from factories import (
    CourierEarningsFactory,
    CourierProfileFactory,
    DeliveryRequestFactory,
    DeliveryTrackingFactory,
    OrderFactory,
)
from delivery.models import DeliveryRequest, DeliveryStatus

pytestmark = [pytest.mark.django_db, pytest.mark.views]

DELIVERY = "/api/v1/delivery"


def _client_for(user):
    client = APIClient()
    client.force_authenticate(user)
    return client


def _grant_model_perms(user, *codenames):
    """DjangoModelPermissions (the DRF default) requires actual model perms
    for unsafe methods — grant them to test users for the actions under test."""
    from django.contrib.auth.models import Permission

    for codename in codenames:
        perm = Permission.objects.get(codename=codename)
        user.user_permissions.add(perm)
        user = User.objects.get(pk=user.pk)
    return user


from users.models import User  # noqa: E402


class TestDeliveryRequestPermissions:
    def test_anonymous_denied(self, anon_api, db):
        """Permission fix regression: deliveries require authentication."""
        DeliveryRequestFactory()
        resp = anon_api.get(f"{DELIVERY}/deliveries/")
        assert resp.status_code in (401, 403)

    def test_customer_sees_own_delivery(self, customer_user, db):
        order = OrderFactory(customer=customer_user.customer_profile)
        mine = DeliveryRequestFactory(order=order)
        DeliveryRequestFactory()
        resp = _client_for(customer_user).get(f"{DELIVERY}/deliveries/")
        ids = [d["id"] for d in resp.data["results"]]
        assert ids == [mine.id]

    def test_courier_sees_only_assigned(self, courier_user, db):
        mine = DeliveryRequestFactory(courier=courier_user.courier_profile)
        DeliveryRequestFactory()
        resp = _client_for(courier_user).get(f"{DELIVERY}/deliveries/")
        ids = [d["id"] for d in resp.data["results"]]
        assert ids == [mine.id]

    def test_admin_sees_all(self, admin_user, db):
        DeliveryRequestFactory(), DeliveryRequestFactory()
        resp = _client_for(admin_user).get(f"{DELIVERY}/deliveries/")
        assert resp.data["count"] == 2


class TestAssignAction:
    def test_assign_courier(self, admin_user, db):
        delivery = DeliveryRequestFactory(status="pending")
        from factories import CourierProfileFactory

        courier = CourierProfileFactory()
        resp = _client_for(admin_user).post(
            f"{DELIVERY}/deliveries/{delivery.id}/assign/",
            {"courier_id": courier.id},
            format="json",
        )
        assert resp.status_code == 200
        delivery.refresh_from_db()
        assert delivery.courier == courier
        assert delivery.status == DeliveryStatus.ASSIGNED
        assert delivery.assigned_at is not None

    def test_assign_missing_courier_id_400(self, admin_user, db):
        delivery = DeliveryRequestFactory()
        resp = _client_for(admin_user).post(
            f"{DELIVERY}/deliveries/{delivery.id}/assign/", {}, format="json"
        )
        assert resp.status_code == 400

    def test_assign_unknown_courier_404(self, admin_user, db):
        delivery = DeliveryRequestFactory()
        resp = _client_for(admin_user).post(
            f"{DELIVERY}/deliveries/{delivery.id}/assign/",
            {"courier_id": 999999},
            format="json",
        )
        assert resp.status_code == 404

    def test_assign_denied_for_non_staff_scoped_users(self, customer_user, db):
        delivery = DeliveryRequestFactory()
        courier = CourierProfileFactory()
        resp = _client_for(customer_user).post(
            f"{DELIVERY}/deliveries/{delivery.id}/assign/",
            {"courier_id": courier.id},
            format="json",
        )
        # customer's queryset doesn't include this delivery -> 403
        # (assign has no object-level guard beyond get_object 403 from
        # DjangoModelPermissions: POST requires add_deliveryrequest)
        assert resp.status_code in (status.HTTP_403_FORBIDDEN, status.HTTP_404_NOT_FOUND)


class TestCourierAcceptDecline:
    def test_accept_assigned_delivery(self, courier_user, db):
        _grant_model_perms(courier_user, "add_deliveryrequest")
        delivery = DeliveryRequestFactory(
            status="assigned", courier=courier_user.courier_profile
        )
        resp = _client_for(courier_user).post(
            f"{DELIVERY}/deliveries/{delivery.id}/accept/"
        )
        assert resp.status_code == 200
        delivery.refresh_from_db()
        assert delivery.status == DeliveryStatus.ACCEPTED

    def test_accept_unassigned_denied(self, courier_user, db):
        _grant_model_perms(courier_user, "add_deliveryrequest")
        delivery = DeliveryRequestFactory(status="pending", courier=None)
        resp = _client_for(courier_user).post(
            f"{DELIVERY}/deliveries/{delivery.id}/accept/"
        )
        # courier's queryset only includes deliveries assigned to them —
        # an unassigned delivery is invisible (404), not 403
        assert resp.status_code in (403, 404)

    def test_accept_other_couriers_delivery_denied(self, courier_user, db):
        _grant_model_perms(courier_user, "add_deliveryrequest")
        from factories import CourierProfileFactory

        other = CourierProfileFactory()
        delivery = DeliveryRequestFactory(status="assigned", courier=other)
        resp = _client_for(courier_user).post(
            f"{DELIVERY}/deliveries/{delivery.id}/accept/"
        )
        # other courier's delivery is invisible in queryset scoping (404);
        # the action's own 403 guard is unreachable via the API
        assert resp.status_code in (403, 404)

    def test_decline_unassigns_courier(self, courier_user, db):
        _grant_model_perms(courier_user, "add_deliveryrequest")
        delivery = DeliveryRequestFactory(
            status="assigned", courier=courier_user.courier_profile
        )
        resp = _client_for(courier_user).post(
            f"{DELIVERY}/deliveries/{delivery.id}/decline/"
        )
        assert resp.status_code == 200
        delivery.refresh_from_db()
        assert delivery.status == DeliveryStatus.DECLINED
        assert delivery.courier is None


class TestUpdateStatus:
    def test_picked_up_updates_order(self, courier_user, db):
        from orders.models import Order

        _grant_model_perms(courier_user, "change_deliveryrequest")
        order = OrderFactory(status="accepted")
        delivery = DeliveryRequestFactory(
            order=order, status="accepted", courier=courier_user.courier_profile
        )
        resp = _client_for(courier_user).patch(
            f"{DELIVERY}/deliveries/{delivery.id}/update-status/",
            {"status": "picked_up"},
            format="json",
        )
        assert resp.status_code == 200
        order.refresh_from_db()
        assert order.status == "picked_up"

    def test_delivered_updates_order_and_frees_courier(self, courier_user, db):
        from orders.models import Order

        _grant_model_perms(courier_user, "change_deliveryrequest")
        courier_user.courier_profile.is_available = False
        courier_user.courier_profile.total_deliveries = 0
        courier_user.courier_profile.save()
        order = OrderFactory(status="picked_up")
        delivery = DeliveryRequestFactory(
            order=order, status="picked_up", courier=courier_user.courier_profile
        )
        resp = _client_for(courier_user).patch(
            f"{DELIVERY}/deliveries/{delivery.id}/update-status/",
            {"status": "delivered"},
            format="json",
        )
        assert resp.status_code == 200
        order.refresh_from_db()
        assert order.status == "delivered"
        courier_user.courier_profile.refresh_from_db()
        assert courier_user.courier_profile.is_available is True
        assert courier_user.courier_profile.total_deliveries == 1

    def test_invalid_status_400(self, courier_user, db):
        from orders.models import Order

        _grant_model_perms(courier_user, "change_deliveryrequest")
        order = OrderFactory()
        delivery = DeliveryRequestFactory(order=order, courier=courier_user.courier_profile)
        resp = _client_for(courier_user).patch(
            f"{DELIVERY}/deliveries/{delivery.id}/update-status/",
            {"status": "teleported"},
            format="json",
        )
        assert resp.status_code == 400


class TestTracking:
    def test_track_updates_location(self, courier_user, db):
        _grant_model_perms(courier_user, "add_deliveryrequest", "change_deliveryrequest")
        order = OrderFactory()
        delivery = DeliveryRequestFactory(
            order=order,
            status="accepted",
            courier=courier_user.courier_profile,
        )
        resp = _client_for(courier_user).post(
            f"{DELIVERY}/deliveries/{delivery.id}/track/",
            {"current_location": {"type": "Point", "coordinates": [32.58, 0.34]}},
            format="json",
        )
        assert resp.status_code == 200, resp.data
        tracking = delivery.tracking.first()
        assert tracking is not None

    def test_track_denied_for_other_courier(self, courier_user, db):
        from factories import CourierProfileFactory

        other = CourierProfileFactory()
        delivery = DeliveryRequestFactory(status="accepted", courier=other)
        resp = _client_for(courier_user).post(
            f"{DELIVERY}/deliveries/{delivery.id}/track/", {}, format="json"
        )
        # other courier's delivery is invisible via queryset scoping (404);
        # the action's own 403 guard is defense-in-depth for non-scoped paths
        assert resp.status_code in (403, 404)

    def test_get_tracking(self, courier_user, db):
        delivery = DeliveryRequestFactory(
            status="accepted", courier=courier_user.courier_profile
        )
        DeliveryTrackingFactory(delivery=delivery, courier=courier_user.courier_profile)
        resp = _client_for(courier_user).get(
            f"{DELIVERY}/deliveries/{delivery.id}/tracking/"
        )
        assert resp.status_code == 200

    def test_get_tracking_none_404(self, courier_user, db):
        delivery = DeliveryRequestFactory(
            status="accepted", courier=courier_user.courier_profile
        )
        resp = _client_for(courier_user).get(
            f"{DELIVERY}/deliveries/{delivery.id}/tracking/"
        )
        assert resp.status_code == 404


class TestNearby:
    def test_nearby_returns_pending_only(self, courier_api, db):
        near = DeliveryRequestFactory(
            status="pending",
            pickup_location__x=32.5825,
            pickup_location__y=0.3476,
        )
        DeliveryRequestFactory(status="assigned")
        DeliveryRequestFactory(status="delivered")
        resp = courier_api.get(
            f"{DELIVERY}/deliveries/nearby/", {"lat": 0.3476, "lng": 32.5825}
        )
        assert resp.status_code == 200
        ids = [d["id"] for d in resp.data["results"]] if isinstance(resp.data, dict) else [d["id"] for d in resp.data]
        assert near.id in ids

    def test_nearby_requires_auth(self, anon_api, db):
        DeliveryRequestFactory(status="pending")
        resp = anon_api.get(
            f"{DELIVERY}/deliveries/nearby/", {"lat": 0.3476, "lng": 32.5825}
        )
        assert resp.status_code in (401, 403)

    def test_nearby_requires_coords(self, courier_api, db):
        resp = courier_api.get(f"{DELIVERY}/deliveries/nearby/")
        assert resp.status_code == 400


class TestCourierEarnings:
    def test_earnings_list(self, courier_user, db):
        CourierEarningsFactory(courier=courier_user.courier_profile, amount=5000)
        CourierEarningsFactory()  # other courier
        resp = _client_for(courier_user).get(f"{DELIVERY}/earnings/")
        rows = resp.data["results"] if isinstance(resp.data, dict) else resp.data
        amounts = [float(e["amount"]) for e in rows]
        assert amounts == [5000.0]

    def test_earnings_list_non_courier_empty(self, customer_user, db):
        CourierEarningsFactory()
        resp = _client_for(customer_user).get(f"{DELIVERY}/earnings/")
        rows = resp.data["results"] if isinstance(resp.data, dict) else resp.data
        assert rows == []

    def test_earnings_summary(self, courier_user, db):
        CourierEarningsFactory(courier=courier_user.courier_profile, amount=5000)
        resp = _client_for(courier_user).get(f"{DELIVERY}/earnings/summary/")
        assert resp.status_code == 200
        assert resp.data["total_earnings"] == 5000
        assert "today_earnings" in resp.data

    def test_earnings_summary_non_courier_403(self, customer_user, db):
        resp = _client_for(customer_user).get(f"{DELIVERY}/earnings/summary/")
        assert resp.status_code == 403

    def test_earnings_requires_auth(self, anon_api, db):
        assert anon_api.get(f"{DELIVERY}/earnings/").status_code in (401, 403)

    def test_calculate_amount_commission(self, db):
        from delivery.models import CourierEarnings
        from factories import CourierProfileFactory

        e = CourierEarningsFactory.build(courier=CourierProfileFactory(), commission_rate=10)
        assert e.calculate_amount(10000) == 9000
