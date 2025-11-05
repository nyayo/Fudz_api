from rest_framework import serializers

from django.contrib.gis.geos import Point

from .models import DeliveryRequest, CourierEarnings
from users.serializers import UserProfileSerializer
from orders.serializers import OrderSerializer 

class DeliveryRequestSerializer(serializers.ModelSerializer):
    # courier = UserProfileSerializer(read_only=True)
    order = OrderSerializer(read_only=True)

    pickup_latitude = serializers.FloatField(write_only=True, required=False)
    pickup_longitude = serializers.FloatField(write_only=True, required=False)
    dropoff_latitude = serializers.FloatField(write_only=True, required=False)
    dropoff_longitude = serializers.FloatField(write_only=True, required=False)

    pickup_coords = serializers.SerializerMethodField()
    dropoff_coords = serializers.SerializerMethodField()

    class Meta:
        model = DeliveryRequest
        fields = [
            "id",
            "order",
            "courier",
            "status",
            "pickup_coords",
            "dropoff_coords",
            "pickup_latitude",
            "pickup_longitude",
            "dropoff_latitude",
            "dropoff_longitude",
            "assigned_at",
            "updated_at",
        ]
        read_only_fields = ["id", "assigned_at", "updated_at"]

    def create(self, validated_data):
        pickup_lat = validated_data.pop("pickup_latitude", None)
        pickup_lng = validated_data.pop("pickup_longitude", None)
        dropoff_lat = validated_data.pop("dropoff_latitude", None)
        dropoff_lng = validated_data.pop("dropoff_longitude", None)

        if pickup_lat and pickup_lng:
            validated_data["pickup_location"] = Point(pickup_lng, pickup_lat)
        if dropoff_lat and dropoff_lng:
            validated_data["dropoff_location"] = Point(dropoff_lng, dropoff_lat)

        return super().create(validated_data)

    def get_pickup_coords(self, obj):
        if obj.pickup_location:
            return {"latitude": obj.pickup_location.y, "longitude": obj.pickup_location.x}
        return None

    def get_dropoff_coords(self, obj):
        if obj.dropoff_location:
            return {"latitude": obj.dropoff_location.y, "longitude": obj.dropoff_location.x}
        return None


class DeliveryStatusUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = DeliveryRequest
        fields = ["status"]


class CourierEarningsSerializer(serializers.ModelSerializer):
    order_id = serializers.IntegerField(source="order.id", read_only=True)
    restaurant_name = serializers.CharField(source="order.restaurant.restaurant_name", read_only=True)
    date = serializers.DateTimeField(source="created_at", read_only=True)

    class Meta:
        model = CourierEarnings
        fields = ["order_id", "restaurant_name", "amount", "commission_rate", "date"]
