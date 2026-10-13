from django.utils import timezone
from rest_framework import serializers
from .models import RestaurantReview

class RestaurantReviewSerializer(serializers.ModelSerializer):
    customer_name = serializers.CharField(source="customer.user.username", read_only=True)

    class Meta:
        model = RestaurantReview
        fields = ["id", "restaurant", "customer", "customer_name", "rating", "comment", "response", "responded_at", "created_at"]
        read_only_fields = ["customer", "restaurant", "customer_name", "rating", "comment", "responded_at", "created_at"]

    def update(self, instance, validated_data):
        instance.response = validated_data.get("response", instance.response)
        instance.responded_at = timezone.now() if instance.response else None
        instance.save(update_fields=["response", "responded_at"])
        return instance
