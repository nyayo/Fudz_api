from decimal import Decimal
from rest_framework import viewsets, status, permissions, generics, serializers
from rest_framework.decorators import action
from rest_framework.response import Response

from django.db import transaction
from django.db.models import Q
from django_filters.rest_framework import DjangoFilterBackend

from .models import DeliveryRequest, DeliveryStatus, CourierEarnings
from .serializers import DeliveryRequestSerializer
from users.models import CourierProfile


class CanManageRestaurantDeliveries(permissions.BasePermission):
    def has_permission(self, request, view):
        user = request.user
        return bool(user and user.is_authenticated and (
            user.is_staff
            or getattr(user, "restaurant_profile", None)
            or (getattr(user, "restaurant_staff_profile", None) and user.restaurant_staff_profile.is_active)
        ))


class AvailableCourierSerializer(serializers.ModelSerializer):
    name = serializers.SerializerMethodField()
    phone = serializers.CharField(source="user.phone", read_only=True)

    class Meta:
        model = CourierProfile
        fields = ["id", "name", "phone", "vehicle_type", "rating", "total_deliveries"]

    def get_name(self, obj):
        return obj.user.get_full_name() or obj.user.username


class AvailableCouriersView(generics.ListAPIView):
    permission_classes = [CanManageRestaurantDeliveries]
    serializer_class = AvailableCourierSerializer

    def get_queryset(self):
        return CourierProfile.objects.filter(is_approved=True, is_available=True).select_related("user").order_by("-rating")


class DeliveryRequestViewSet(viewsets.ModelViewSet):
    permission_classes = [CanManageRestaurantDeliveries]
    queryset = DeliveryRequest.objects.select_related("order", "courier").all()
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ["status"]

    def get_queryset(self):
        qs = super().get_queryset()
        user = self.request.user
        if user.is_staff:
            pass
        else:
            restaurant = getattr(user, "restaurant_profile", None)
            staff = getattr(user, "restaurant_staff_profile", None)
            if restaurant:
                qs = qs.filter(order__restaurant=restaurant)
            elif staff and staff.is_active:
                qs = qs.filter(order__restaurant=staff.restaurant)
            else:
                return qs.none()

        search = (self.request.query_params.get("search") or "").strip()
        for term in search.split():
            term_filter = (
                Q(courier__user__username__icontains=term)
                | Q(courier__user__first_name__icontains=term)
                | Q(courier__user__last_name__icontains=term)
                | Q(courier__user__phone__icontains=term)
            )
            order_number = term.lstrip("#")
            if order_number.isdecimal():
                term_filter |= Q(order__id=int(order_number))
            qs = qs.filter(term_filter)
        return qs

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

        return Response(DeliveryRequestSerializer(delivery).data, status=200)

    @action(detail=True, methods=["post"], url_path="complete")
    def complete(self, request, pk=None):
        """Admin marks delivery as completed, creates courier earnings."""
        delivery = self.get_object()

        if delivery.status not in [DeliveryStatus.ASSIGNED, DeliveryStatus.ACCEPTED, DeliveryStatus.PICKED_UP]:
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

        return Response(DeliveryRequestSerializer(delivery).data)

