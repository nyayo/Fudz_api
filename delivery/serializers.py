from rest_framework import serializers
from drf_spectacular.utils import extend_schema_field

from .models import DeliveryRequest
from orders.serializers import OrderSerializer


class DeliveryRequestSerializer(serializers.ModelSerializer):
    """Serializer for delivery request details (admin use)."""

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
        from django.contrib.gis.geos import Point

        pickup_lat = validated_data.pop("pickup_latitude", None)
        pickup_lng = validated_data.pop("pickup_longitude", None)
        dropoff_lat = validated_data.pop("dropoff_latitude", None)
        dropoff_lng = validated_data.pop("dropoff_longitude", None)

        if pickup_lat and pickup_lng:
            validated_data["pickup_location"] = Point(pickup_lng, pickup_lat)
        if dropoff_lat and dropoff_lng:
            validated_data["dropoff_location"] = Point(dropoff_lng, dropoff_lat)

        return super().create(validated_data)

    @extend_schema_field(
        {
            "type": "object",
            "properties": {
                "latitude": {"type": "number"},
                "longitude": {"type": "number"},
            },
            "nullable": True,
        }
    )
    def get_pickup_coords(self, obj):
        if obj.pickup_location:
            return {
                "latitude": obj.pickup_location.y,
                "longitude": obj.pickup_location.x,
            }
        return None

    @extend_schema_field(
        {
            "type": "object",
            "properties": {
                "latitude": {"type": "number"},
                "longitude": {"type": "number"},
            },
            "nullable": True,
        }
    )
    def get_dropoff_coords(self, obj):
        if obj.dropoff_location:
            return {
                "latitude": obj.dropoff_location.y,
                "longitude": obj.dropoff_location.x,
            }
        return None
