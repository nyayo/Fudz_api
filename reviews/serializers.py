from rest_framework import serializers
from .models import RestaurantReview

class RestaurantReviewSerializer(serializers.ModelSerializer):
    customer_name = serializers.CharField(source="customer.user.username", read_only=True)

    class Meta:
        model = RestaurantReview
        fields = ["id", "restaurant", "customer", "customer_name", "rating", "comment", "created_at"]
        read_only_fields = ["customer"]
