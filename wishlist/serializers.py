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
