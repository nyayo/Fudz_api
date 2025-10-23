from rest_framework import viewsets, status, generics, permissions
from rest_framework.decorators import action
from rest_framework.response import Response

from django.contrib.gis.geos import Point
from django.contrib.gis.db.models.functions import Distance
from django.db.models import Sum
from django.utils import timezone

from .models import DeliveryRequest, CourierEarnings
from .serializers import DeliveryRequestSerializer, DeliveryStatusUpdateSerializer, CourierEarningsSerializer
from users.models import CourierProfile

class DeliveryRequestViewSet(viewsets.ModelViewSet):
    queryset = DeliveryRequest.objects.select_related("order", "courier").all()

    def get_queryset(self):
        user = self.request.user
        if hasattr(user, "customer_profile"):
            return self.queryset.filter(order__customer=user.customer_profile)
        elif hasattr(user, "courier_profile"):
            print(f"Courier {user.username} accessing their deliveries")
            return self.queryset.filter(courier=user.courier_profile)
        elif user.is_staff:
            return self.queryset
        return DeliveryRequest.objects.none()

    def get_serializer_class(self):
        if self.action in ["update_status", "partial_update"]:
            return DeliveryStatusUpdateSerializer
        return DeliveryRequestSerializer

    """----------- Custom Actions -----------"""

    @action(detail=True, methods=["post"], url_path="assign")
    def assign(self, request, pk=None):
        """Assign courier manually (done after restaurant accepts order)"""
        delivery = self.get_object()
        courier_id = request.data.get("courier_id")

        if not courier_id:
            return Response({"error": "courier_id required"}, status=400)
        try:
            courier = CourierProfile.objects.get(id=courier_id)
        except CourierProfile.DoesNotExist:
            return Response({"error": "Courier not found"}, status=404)

        delivery.assign_to(courier)
        return Response({"message": "Courier assigned successfully"}, status=200)

    @action(detail=False, methods=["get"], url_path="nearby")
    def nearby(self, request):
        """Get nearby pending deliveries for courier"""
        lat = request.query_params.get("lat")
        lng = request.query_params.get("lng")

        if not lat or not lng:
            return Response({"error": "lat and lng required"}, status=400)

        point = Point(float(lng), float(lat), srid=4326)
        deliveries = (
            DeliveryRequest.objects.filter(status="pending")
            .annotate(distance=Distance("pickup_location", point))
            .order_by("distance")[:10]
        )

        serializer = self.get_serializer(deliveries, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=["post"], url_path="accept")
    def accept(self, request, pk=None):
        """Courier accepts delivery"""
        delivery = self.get_object()
        courier = request.user.courier_profile

        if delivery.status != "assigned" or delivery.courier != courier:
            return Response({"error": "You are not assigned to this delivery"}, status=403)

        delivery.mark_status("accepted")
        return Response({"message": "Delivery accepted"}, status=200)

    @action(detail=True, methods=["post"], url_path="decline")
    def decline(self, request, pk=None):
        """Courier declines assigned delivery"""
        delivery = self.get_object()
        courier = request.user.courier_profile

        if delivery.status != "assigned" or delivery.courier != courier:
            return Response({"error": "You are not assigned to this delivery"}, status=403)

        delivery.mark_status("declined")
        delivery.courier = None
        delivery.save()

        return Response({"message": "Delivery declined"}, status=200)

    @action(detail=True, methods=["patch"], url_path="update-status")
    def update_status(self, request, pk=None):
        """Courier updates delivery progress"""
        delivery = self.get_object()
        serializer = DeliveryStatusUpdateSerializer(delivery, data=request.data, partial=True)
        if serializer.is_valid():
            new_status = serializer.validated_data["status"]
            serializer.save()

            if new_status in ["delivered", "cancelled"] and delivery.courier:
                delivery.courier.is_available = True
                delivery.courier.save()

            return Response({"message": f"Status updated to {new_status}"})
        return Response(serializer.errors, status=400)
    
    
class CourierEarningsListView(generics.ListAPIView):
    serializer_class = CourierEarningsSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return CourierEarnings.objects.filter(
            courier=self.request.user.courierprofile
        ).order_by("-created_at")

class CourierEarningsSummaryView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        courier = request.user.courierprofile
        total_earnings = CourierEarnings.objects.filter(courier=courier).aggregate(
            total=Sum("amount")
        )["total"] or 0

        today_earnings = CourierEarnings.objects.filter(
            courier=courier, created_at__date__exact=timezone.now().date()
        ).aggregate(total=Sum("amount"))["total"] or 0

        return Response({
            "total_earnings": total_earnings,
            "today_earnings": today_earnings,
        })    

