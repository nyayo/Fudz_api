from rest_framework import serializers

from .models import MenuCategory, MenuCategoryImage, MenuItem, MenuItemImage, Promotion
from users.models import RestaurantProfile

class PromotionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Promotion
        fields = [
            'id', 'name', 'description', 'discount',
            'start_date', 'end_date', 'is_active'
        ]
        
class MenuItemImageSerializer(serializers.ModelSerializer):
    def create(self, validated_data):
        menu_item_id = self.context['menu_item_id']
        return MenuItemImage.objects.create(menu_item_id=menu_item_id, **validated_data)
    
    class Meta:
        model = MenuItemImage
        fields = ['id', 'image']
        

class MenuItemSerializer(serializers.ModelSerializer):
    restaurant_name = serializers.CharField(source='restaurant.name', read_only=True)
    category_name = serializers.CharField(source='category.name', read_only=True)
    promotions = PromotionSerializer(many=True, read_only=True)
    
    restaurant = serializers.PrimaryKeyRelatedField(
        queryset=None, 
        required=False, 
        allow_null=True,
        read_only=True
    )
    images = MenuItemImageSerializer(many=True, read_only=True)

    class Meta:
        model = MenuItem
        fields = [
            'id', 'title', 'description', 'restaurant', 'restaurant_name',
            'category', 'category_name', 'price', 'is_available',
            'is_featured', 'prep_time_minutes', 'allergens',
            'promotions', 'images', 'created_at', 'updated_at'
        ]
        read_only_fields = ['created_at', 'updated_at']

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        request = self.context.get('request')
        
        if request and hasattr(request, 'user'):
            if hasattr(request.user, 'restaurant_profile') and not request.user.is_staff:
                self.fields['restaurant'].queryset = request.user.restaurant_profile.__class__.objects.filter(
                    id=request.user.restaurant_profile.id
                )
            else:
                from users.models import RestaurantProfile
                self.fields['restaurant'].queryset = RestaurantProfile.objects.all()

    def validate(self, data):
        """Validate that category belongs to the same restaurant"""
        request = self.context.get('request')
        
        if (request and hasattr(request.user, 'restaurant_profile') and 
            not request.user.is_staff and not data.get('restaurant')):
            data['restaurant'] = request.user.restaurant_profile
        
        restaurant = data.get('restaurant')
        category = data.get('category')
        
        if category and restaurant and category.restaurant != restaurant:
            raise serializers.ValidationError(
                "Category must belong to the same restaurant."
            )
            
        if not restaurant:
            raise serializers.ValidationError(
                "Restaurant is required."
            )
            
        return data
    

class MenuCategoryImageSerializer(serializers.ModelSerializer):
    def create(self, validated_data):
        category_id = self.context['category_id']
        return MenuCategoryImage.objects.create(category_id=category_id, **validated_data)
    
    class Meta:
        model = MenuCategoryImage
        fields = ['id', 'image']


class MenuCategorySerializer(serializers.ModelSerializer):
    items_count = serializers.IntegerField(read_only=True)
    restaurant_name = serializers.CharField(source='restaurant.restaurant_name', read_only=True)
    menu_items = MenuItemSerializer(source='items', many=True, read_only=True)
    
    restaurant = serializers.PrimaryKeyRelatedField(
        queryset=None, 
        required=False, 
        allow_null=True,
        read_only=True
    )
    category_image = MenuCategoryImageSerializer(many=True, read_only=True)

    class Meta:
        model = MenuCategory
        fields = [
            'id', 'name', 'description', 'restaurant', 'restaurant_name',
            'position', 'is_active', 'items_count', 'menu_items', 'category_image',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['created_at', 'updated_at']

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        request = self.context.get('request')
        
        if request and hasattr(request, 'user'):
            if hasattr(request.user, 'restaurant_profile') and not request.user.is_staff:
                self.fields['restaurant'].queryset = request.user.restaurant_profile.__class__.objects.filter(
                    id=request.user.restaurant_profile.id
                )
            else:
                from users.models import RestaurantProfile
                self.fields['restaurant'].queryset = RestaurantProfile.objects.all()

    def validate(self, data):
        """Auto-assign restaurant for restaurant owners and validate"""
        request = self.context.get('request')
        
        if (request and hasattr(request.user, 'restaurant_profile') and 
            not request.user.is_staff and not data.get('restaurant')):
            data['restaurant'] = request.user.restaurant_profile
        
        if not data.get('restaurant'):
            raise serializers.ValidationError(
                "Restaurant is required."
            )
            
        return data

class MenuCategoryListSerializer(serializers.ModelSerializer):
    """Simplified serializer for listing categories without menu items"""
    items_count = serializers.IntegerField(read_only=True)
    restaurant_name = serializers.CharField(source='restaurant.restaurant_name', read_only=True)
    restaurant = serializers.PrimaryKeyRelatedField(
        queryset=None, 
        required=False, 
        allow_null=True,
        read_only=True
    )
    category_image = MenuCategoryImageSerializer(many=True, read_only=True)

    class Meta:
        model = MenuCategory
        fields = [
            'id', 'name', 'description', 'restaurant', 'restaurant_name',
            'position', 'is_active', 'items_count', 'category_image'
        ]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        request = self.context.get('request')
        
        if request and hasattr(request, 'user'):
            if hasattr(request.user, 'restaurant_profile') and not request.user.is_staff:
                self.fields['restaurant'].queryset = request.user.restaurant_profile.__class__.objects.filter(
                    id=request.user.restaurant_profile.id
                )
            else:
                from users.models import RestaurantProfile
                self.fields['restaurant'].queryset = RestaurantProfile.objects.all()

    def validate(self, data):
        """Auto-assign restaurant for restaurant owners and validate"""
        request = self.context.get('request')
        
        if (request and hasattr(request.user, 'restaurant_profile') and 
            not request.user.is_staff and not data.get('restaurant')):
            data['restaurant'] = request.user.restaurant_profile
        
        if not data.get('restaurant'):
            raise serializers.ValidationError(
                "Restaurant is required."
            )
            
        return data
    
    
class RestaurantProfileSerializer(serializers.ModelSerializer):
    menu_items_count = serializers.IntegerField(read_only=True)
    categories_count = serializers.IntegerField(read_only=True)
    avg_rating = serializers.DecimalField(max_digits=3, decimal_places=2, read_only=True)
    owner_name = serializers.CharField(source='user.first_name', read_only=True)
    phone = serializers.CharField(source='user.phone', read_only=True)

    categories = MenuCategorySerializer(many=True, read_only=True)
    promotions = PromotionSerializer(many=True, read_only=True)
    
    class Meta:
        model = RestaurantProfile
        fields = [
            'id', 'restaurant_name', 'business_license', 'address',
            'opening_hours', 'rating', 'avg_rating', 'is_approved',
            'is_active', 'menu_items_count', 'categories_count',
            'owner_name', 'phone', 'categories', 'promotions'
        ]    
    

class RestaurantListSerializer(serializers.ModelSerializer):
    """Simplified serializer for restaurant listing without detailed menu"""
    menu_items_count = serializers.IntegerField(read_only=True)
    categories_count = serializers.IntegerField(read_only=True)
    avg_rating = serializers.DecimalField(max_digits=3, decimal_places=2, read_only=True)
    
    class Meta:
        model = RestaurantProfile
        fields = [
            'id', 'restaurant_name', 'address', 'rating', 'avg_rating',
            'menu_items_count', 'categories_count', 'opening_hours'
        ]

