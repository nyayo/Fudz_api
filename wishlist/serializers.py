from rest_framework import serializers
from .models import WishlistItem
from restaurants.models import MenuItem
from restaurants.serializers import MenuItemSerializer  # assumes you already have this

class WishlistItemSerializer(serializers.ModelSerializer):
    menu_item = MenuItemSerializer(read_only=True)
    menu_item_id = serializers.PrimaryKeyRelatedField(
        queryset=MenuItem.objects.all(), 
        source='menu_item', 
        write_only=True
    )

    class Meta:
        model = WishlistItem
        fields = ['id', 'menu_item', 'menu_item_id', 'added_at']


class AdminWishlistItemSerializer(serializers.ModelSerializer):
    menu_item = MenuItemSerializer(read_only=True)
    customer_id = serializers.IntegerField(source="wishlist.customer.user_id", read_only=True)
    customer_name = serializers.SerializerMethodField()
    customer_email = serializers.EmailField(source="wishlist.customer.user.email", read_only=True, allow_null=True)
    restaurant_name = serializers.CharField(source="menu_item.restaurant.restaurant_name", read_only=True)

    class Meta:
        model = WishlistItem
        fields = ["id", "customer_id", "customer_name", "customer_email", "menu_item", "restaurant_name", "added_at"]

    def get_customer_name(self, obj):
        return obj.wishlist.customer.user.get_full_name() or obj.wishlist.customer.user.username
