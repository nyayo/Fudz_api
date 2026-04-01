from rest_framework import serializers
from drf_spectacular.utils import extend_schema_field
from drf_spectacular.types import OpenApiTypes

from django.contrib.gis.geos import Point

from .models import DeliveryRequest, DeliveryTracking, CourierEarnings
from users.serializers import UserProfileSerializer
from orders.serializers import OrderSerializer 

class DeliveryRequestSerializer(serializers.ModelSerializer):
    """Serializer for delivery request details"""
    order = OrderSerializer(read_only=True)

    pickup_latitude = serializers.FloatField(write_only=True, required=False, help_text="Pickup location latitude")
    pickup_longitude = serializers.FloatField(write_only=True, required=False, help_text="Pickup location longitude")
    dropoff_latitude = serializers.FloatField(write_only=True, required=False, help_text="Dropoff location latitude")
    dropoff_longitude = serializers.FloatField(write_only=True, required=False, help_text="Dropoff location longitude")

    pickup_coords = serializers.SerializerMethodField(help_text="Pickup coordinates")
    dropoff_coords = serializers.SerializerMethodField(help_text="Dropoff coordinates")

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

    @extend_schema_field({
        'type': 'object',
        'properties': {
            'latitude': {'type': 'number'},
            'longitude': {'type': 'number'}
        },
        'nullable': True
    })
    def get_pickup_coords(self, obj):
        if obj.pickup_location:
            return {"latitude": obj.pickup_location.y, "longitude": obj.pickup_location.x}
        return None

    @extend_schema_field({
        'type': 'object',
        'properties': {
            'latitude': {'type': 'number'},
            'longitude': {'type': 'number'}
        },
        'nullable': True
    })
    def get_dropoff_coords(self, obj):
        if obj.dropoff_location:
            return {"latitude": obj.dropoff_location.y, "longitude": obj.dropoff_location.x}
        return None


class DeliveryStatusUpdateSerializer(serializers.ModelSerializer):
    """Serializer for updating delivery status"""
    class Meta:
        model = DeliveryRequest
        fields = ["status"]
        extra_kwargs = {
            'status': {'help_text': 'Delivery status: pending, assigned, accepted, declined, picked_up, delivered, cancelled'},
        }


class CourierEarningsSerializer(serializers.ModelSerializer):
    """Serializer for courier earnings details"""
    order_id = serializers.IntegerField(source="order.id", read_only=True)
    restaurant_name = serializers.CharField(source="order.restaurant.restaurant_name", read_only=True)
    date = serializers.DateTimeField(source="created_at", read_only=True)

    class Meta:
        model = CourierEarnings
        fields = ["order_id", "restaurant_name", "amount", "commission_rate", "date"]


class NearbyQuerySerializer(serializers.Serializer):
    lat = serializers.FloatField(min_value=-90, max_value=90)
    lng = serializers.FloatField(min_value=-180, max_value=180)


class DeliveryTrackingSerializer(serializers.ModelSerializer):
    """Serializer for real-time delivery tracking"""
    latitude = serializers.FloatField(write_only=True, help_text="Current latitude of courier")
    longitude = serializers.FloatField(write_only=True, help_text="Current longitude of courier")
    current_coords = serializers.SerializerMethodField(help_text="Current location coordinates")

    class Meta:
        model = DeliveryTracking
        fields = ["id", "delivery", "courier", "latitude", "longitude", "current_coords", "last_updated"]
        read_only_fields = ["id", "delivery", "courier", "last_updated"]

    def get_current_coords(self, obj):
        if obj.current_location:
            return {"latitude": obj.current_location.y, "longitude": obj.current_location.x}
        return None

    def create(self, validated_data):
        lat = validated_data.pop("latitude")
        lng = validated_data.pop("longitude")
        validated_data["current_location"] = Point(lng, lat, srid=4326)
        return super().create(validated_data)

    def update(self, instance, validated_data):
        lat = validated_data.pop("latitude", None)
        lng = validated_data.pop("longitude", None)
        if lat is not None and lng is not None:
            validated_data["current_location"] = Point(lng, lat, srid=4326)
        return super().update(instance, validated_data)
