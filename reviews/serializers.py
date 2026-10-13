from django.utils import timezone
from rest_framework import serializers
from .models import RestaurantReview

class RestaurantReviewSerializer(serializers.ModelSerializer):
    customer_name = serializers.SerializerMethodField()

    class Meta:
        model = RestaurantReview
        fields = ["id", "restaurant", "customer", "customer_name", "rating", "comment", "response", "responded_at", "created_at"]
        read_only_fields = ["customer", "restaurant", "customer_name", "rating", "comment", "responded_at", "created_at"]

    def get_customer_name(self, obj):
        user = obj.customer.user
        return user.get_full_name().strip() or user.get_username() or user.email

    def update(self, instance, validated_data):
        instance.response = validated_data.get("response", instance.response)
        instance.responded_at = timezone.now() if instance.response else None
        instance.save(update_fields=["response", "responded_at"])
        return instance
