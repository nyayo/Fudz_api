from rest_framework import serializers

from users.models import RestaurantProfile

from .models import (
    MenuCategory,
    MenuCategoryImage,
    MenuItem,
    MenuItemImage,
    Promotion,
)


class PromotionSerializer(serializers.ModelSerializer):
    restaurant_name = serializers.CharField(source="restaurant.restaurant_name", read_only=True)
    is_currently_active = serializers.SerializerMethodField()

    class Meta:
        model = Promotion
        fields = [
            "id",
            "restaurant",
            "restaurant_name",
            "name",
            "description",
            "discount",
            "start_date",
            "end_date",
            "is_active",
            "is_currently_active",
            "created_at",
        ]
        read_only_fields = ["created_at"]

    def get_is_currently_active(self, obj):
        """Check if promotion is active and within date range"""
        from django.utils import timezone

        now = timezone.now()
        return obj.is_active and obj.start_date <= now <= obj.end_date

    def validate(self, data):
        """Ensure end_date is after start_date"""
        if data.get("start_date") and data.get("end_date"):
            if data["end_date"] <= data["start_date"]:
                raise serializers.ValidationError("End date must be after start date")
        return data


class MenuItemImageSerializer(serializers.ModelSerializer):
    def create(self, validated_data):
        menu_item_id = self.context["menu_item_id"]
        return MenuItemImage.objects.create(menu_item_id=menu_item_id, **validated_data)

    class Meta:
        model = MenuItemImage
        fields = ["id", "image"]


class MenuItemSerializer(serializers.ModelSerializer):
    restaurant_name = serializers.CharField(source="restaurant.restaurant_name", read_only=True)
    category_name = serializers.CharField(source="category.name", read_only=True)
    promotions = PromotionSerializer(many=True, read_only=True)
    restaurant = serializers.PrimaryKeyRelatedField(queryset=None, required=False, allow_null=True, read_only=True)
    promotion_ids = serializers.PrimaryKeyRelatedField(
        many=True,
        write_only=True,
        queryset=Promotion.objects.all(),
        source="promotions",
        required=False,
    )
    discounted_price = serializers.SerializerMethodField()
    images = MenuItemImageSerializer(many=True, read_only=True)

    class Meta:
        model = MenuItem
        fields = [
            "id",
            "title",
            "description",
            "restaurant",
            "restaurant_name",
            "category",
            "category_name",
            "price",
            "discounted_price",
            "is_available",
            "is_featured",
            "prep_time_minutes",
            "allergens",
            "promotions",
            "promotion_ids",
            "images",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["created_at", "updated_at"]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        request = self.context.get("request")

        if request and hasattr(request, "user"):
            if hasattr(request.user, "restaurant_profile") and not request.user.is_staff:
                self.fields["restaurant"].queryset = request.user.restaurant_profile.__class__.objects.filter(id=request.user.restaurant_profile.id)
            else:
                from users.models import RestaurantProfile

                self.fields["restaurant"].queryset = RestaurantProfile.objects.all()

    def get_discounted_price(self, obj):
        """Calculate price after applying active promotions"""
        from django.utils import timezone

        now = timezone.now()

        active_promotions = obj.promotions.filter(is_active=True, start_date__lte=now, end_date__gte=now)

        if not active_promotions.exists():
            return float(obj.price)

        max_discount = max(promo.discount for promo in active_promotions)
        discounted = float(obj.price) * (1 - max_discount / 100)
        return round(discounted, 2)

    def validate_promotion_ids(self, promotions):
        """Ensure promotions belong to the same restaurant"""
        restaurant = self.initial_data.get("restaurant")
        if restaurant:
            for promotion in promotions:
                if promotion.restaurant_id != int(restaurant):
                    raise serializers.ValidationError(f"Promotion '{promotion.name}' does not belong to this restaurant")
        return promotions

    def validate(self, data):
        """Validate that category belongs to the same restaurant"""
        request = self.context.get("request")

        if request and hasattr(request.user, "restaurant_profile") and not request.user.is_staff and not data.get("restaurant"):
            data["restaurant"] = request.user.restaurant_profile

        restaurant = data.get("restaurant")
        category = data.get("category")

        if category and restaurant and category.restaurant != restaurant:
            raise serializers.ValidationError("Category must belong to the same restaurant.")

        if not restaurant:
            raise serializers.ValidationError("Restaurant is required.")

        return data


class MenuCategoryImageSerializer(serializers.ModelSerializer):
    def create(self, validated_data):
        category_id = self.context["category_id"]
        return MenuCategoryImage.objects.create(category_id=category_id, **validated_data)

    class Meta:
        model = MenuCategoryImage
        fields = ["id", "image"]


class MenuCategorySerializer(serializers.ModelSerializer):
    items_count = serializers.IntegerField(read_only=True)
    restaurant_name = serializers.CharField(source="restaurant.restaurant_name", read_only=True)
    menu_items = MenuItemSerializer(source="items", many=True, read_only=True)

    restaurant = serializers.PrimaryKeyRelatedField(queryset=None, required=False, allow_null=True, read_only=True)
    category_image = MenuCategoryImageSerializer(many=True, read_only=True)

    class Meta:
        model = MenuCategory
        fields = [
            "id",
            "name",
            "description",
            "restaurant",
            "restaurant_name",
            "position",
            "is_active",
            "items_count",
            "menu_items",
            "category_image",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["created_at", "updated_at"]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        request = self.context.get("request")

        if request and hasattr(request, "user"):
            if hasattr(request.user, "restaurant_profile") and not request.user.is_staff:
                self.fields["restaurant"].queryset = request.user.restaurant_profile.__class__.objects.filter(id=request.user.restaurant_profile.id)
            else:
                from users.models import RestaurantProfile

                self.fields["restaurant"].queryset = RestaurantProfile.objects.all()

    def validate(self, data):
        """Auto-assign restaurant for restaurant owners and validate"""
        request = self.context.get("request")

        if request and hasattr(request.user, "restaurant_profile") and not request.user.is_staff and not data.get("restaurant"):
            data["restaurant"] = request.user.restaurant_profile

        if not data.get("restaurant"):
            raise serializers.ValidationError("Restaurant is required.")

        return data


class MenuCategoryListSerializer(serializers.ModelSerializer):
    """Simplified serializer for listing categories without menu items"""

    items_count = serializers.IntegerField(read_only=True)
    restaurant_name = serializers.CharField(source="restaurant.restaurant_name", read_only=True)
    restaurant = serializers.PrimaryKeyRelatedField(queryset=None, required=False, allow_null=True, read_only=True)
    category_image = MenuCategoryImageSerializer(many=True, read_only=True)

    class Meta:
        model = MenuCategory
        fields = [
            "id",
            "name",
            "description",
            "restaurant",
            "restaurant_name",
            "position",
            "is_active",
            "items_count",
            "category_image",
        ]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        request = self.context.get("request")

        if request and hasattr(request, "user"):
            if hasattr(request.user, "restaurant_profile") and not request.user.is_staff:
                self.fields["restaurant"].queryset = request.user.restaurant_profile.__class__.objects.filter(id=request.user.restaurant_profile.id)
            else:
                from users.models import RestaurantProfile

                self.fields["restaurant"].queryset = RestaurantProfile.objects.all()

    def validate(self, data):
        """Auto-assign restaurant for restaurant owners and validate"""
        request = self.context.get("request")

        if request and hasattr(request.user, "restaurant_profile") and not request.user.is_staff and not data.get("restaurant"):
            data["restaurant"] = request.user.restaurant_profile

        if not data.get("restaurant"):
            raise serializers.ValidationError("Restaurant is required.")

        return data


class RestaurantProfileSerializer(serializers.ModelSerializer):
    menu_items_count = serializers.IntegerField(read_only=True)
    categories_count = serializers.IntegerField(read_only=True)
    avg_rating = serializers.DecimalField(max_digits=3, decimal_places=2, read_only=True)
    owner_name = serializers.CharField(source="user.first_name", read_only=True)
    phone = serializers.CharField(source="user.phone", read_only=True)

    categories = MenuCategorySerializer(many=True, read_only=True)
    promotions = PromotionSerializer(many=True, read_only=True)

    class Meta:
        model = RestaurantProfile
        fields = [
            "id",
            "restaurant_name",
            "business_license",
            "address",
            "opening_hours",
            "rating",
            "avg_rating",
            "is_approved",
            "is_active",
            "menu_items_count",
            "categories_count",
            "owner_name",
            "phone",
            "categories",
            "promotions",
        ]


class RestaurantListSerializer(serializers.ModelSerializer):
    """Simplified serializer for restaurant listing without detailed menu"""

    menu_items_count = serializers.IntegerField(read_only=True)
    categories_count = serializers.IntegerField(read_only=True)
    avg_rating = serializers.DecimalField(max_digits=3, decimal_places=2, read_only=True)

    class Meta:
        model = RestaurantProfile
        fields = [
            "id",
            "restaurant_name",
            "address",
            "rating",
            "avg_rating",
            "menu_items_count",
            "categories_count",
            "opening_hours",
        ]
