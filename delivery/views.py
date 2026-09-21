from decimal import Decimal
from rest_framework import viewsets, status, permissions
from rest_framework.decorators import action
from rest_framework.response import Response

from django.db import transaction

from .models import DeliveryRequest, DeliveryStatus, CourierEarnings
from .serializers import DeliveryRequestSerializer
from users.models import CourierProfile


class DeliveryRequestViewSet(viewsets.ModelViewSet):
    permission_classes = [permissions.IsAuthenticated]
    queryset = DeliveryRequest.objects.select_related("order", "courier").all()
    permission_classes = [permissions.IsAdminUser]

    def get_serializer_class(self):
        return DeliveryRequestSerializer

    @action(detail=True, methods=["post"], url_path="assign")
    def assign(self, request, pk=None):
        """Admin assigns a courier to a delivery."""
        delivery = self.get_object()
        courier_id = request.data.get("courier_id")

        if not courier_id:
            return Response({"error": "courier_id required"}, status=400)
        try:
            courier = CourierProfile.objects.get(
                id=courier_id, is_approved=True, is_available=True
            )
        except CourierProfile.DoesNotExist:
            return Response(
                {"error": "Courier not found or not available"}, status=404
            )

        with transaction.atomic():
            delivery.assign_to(courier)
            courier.is_available = False
            courier.save(update_fields=["is_available"])
            delivery.order.courier = courier
            delivery.order.save(update_fields=["courier"])

        return Response({"message": "Courier assigned successfully"}, status=200)

    @action(detail=True, methods=["post"], url_path="complete")
    def complete(self, request, pk=None):
        """Admin marks delivery as completed, creates courier earnings."""
        delivery = self.get_object()

        if delivery.status not in [DeliveryStatus.ASSIGNED, DeliveryStatus.ACCEPTED]:
            return Response(
                {"error": f"Cannot complete delivery in '{delivery.status}' status"},
                status=400,
            )

        with transaction.atomic():
            delivery.status = DeliveryStatus.DELIVERED
            delivery.save()

            # Update order status
            delivery.order.status = "delivered"
            delivery.order.save(update_fields=["status"])

            # Create earnings record
            if delivery.courier:
                order_total = delivery.order.total_price
                commission_rate = Decimal("10.00")
                commission = (commission_rate / 100) * order_total
                courier_earning = order_total - commission

                CourierEarnings.objects.create(
                    courier=delivery.courier,
                    order=delivery.order,
                    amount=courier_earning,
                    commission_rate=commission_rate,
                )
                delivery.courier.is_available = True
                delivery.courier.total_deliveries += 1
                delivery.courier.earnings_balance += courier_earning
                delivery.courier.save()

        return Response({"message": "Delivery completed and earnings recorded"})
