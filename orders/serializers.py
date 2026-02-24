from decimal import Decimal

from django.contrib.gis.geos import Point
from django.db import transaction
from django.utils import timezone
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from restaurants.models import MenuItem, MenuItemImage, Promotion
from restaurants.serializers import PromotionSerializer
from users.models import CustomerProfile

from .models import Cart, CartItem, Order, OrderItem


class MenuItemImageSimpleSerializer(serializers.ModelSerializer):
    class Meta:
        model = MenuItemImage
        fields = ["id", "image"]


class SimpleMenuSerializer(serializers.ModelSerializer):
    images = MenuItemImageSimpleSerializer(many=True, read_only=True)
    promotions = PromotionSerializer(many=True, read_only=True)

    class Meta:
        model = MenuItem
        fields = ["id", "title", "price", "images", "promotions"]


class CartItemSerializer(serializers.ModelSerializer):
    menu_item = SimpleMenuSerializer()
    total_price = serializers.SerializerMethodField()
    unit_price = serializers.SerializerMethodField()

    @extend_schema_field(OpenApiTypes.DECIMAL)
    def get_total_price(self, cart_item: CartItem):
        return float(cart_item.qty * self._get_effective_price(cart_item.menu_item))

    def get_unit_price(self, cart_item: CartItem):
        return float(self._get_effective_price(cart_item.menu_item))

    def _get_effective_price(self, menu_item):
        """Get the effective price considering active promotions."""
        now = timezone.now()
        active_promos = menu_item.promotions.filter(
            is_active=True, start_date__lte=now, end_date__gte=now
        )
        if active_promos.exists():
            highest_discount = max(p.discount for p in active_promos)
            return menu_item.price * Decimal(str(1 - highest_discount / 100))
        return menu_item.price

    class Meta:
        model = CartItem
        fields = ["id", "menu_item", "qty", "total_price", "unit_price"]


class CartSerializer(serializers.ModelSerializer):
    id = serializers.UUIDField(read_only=True)
    items = CartItemSerializer(many=True, read_only=True)
    total_price = serializers.SerializerMethodField()
    restaurant_id = serializers.SerializerMethodField()

    @extend_schema_field(OpenApiTypes.DECIMAL)
    def get_total_price(self, cart: Cart):
        now = timezone.now()
        total = Decimal("0")
        for item in cart.items.all():
            active_promos = item.menu_item.promotions.filter(
                is_active=True, start_date__lte=now, end_date__gte=now
            )
            if active_promos.exists():
                highest_discount = max(p.discount for p in active_promos)
                price = item.menu_item.price * Decimal(str(1 - highest_discount / 100))
            else:
                price = item.menu_item.price
            total += item.qty * price
        return float(total)

    @extend_schema_field(OpenApiTypes.INT)
    def get_restaurant_id(self, cart: Cart):
        first_item = cart.items.first()
        if first_item and first_item.menu_item:
            return first_item.menu_item.restaurant_id
        return None

    class Meta:
        model = Cart
        fields = ["id", "items", "total_price", "restaurant_id"]


class AddCartItemSerializer(serializers.ModelSerializer):
    menu_item_id = serializers.IntegerField()

    def validate_menu_item_id(self, value):
        if not MenuItem.objects.filter(pk=value).exists():
            raise serializers.ValidationError(
                "No available menu item with the given ID was found."
            )
        return value

    def validate(self, attrs):
        cart_id = self.context["cart_id"]
        menu_item_id = attrs["menu_item_id"]

        try:
            MenuItem.objects.select_related("restaurant").get(pk=menu_item_id)
        except MenuItem.DoesNotExist:
            raise serializers.ValidationError("Menu item not found.")

        # existing_items = CartItem.objects.filter(cart_id=cart_id).select_related('menu_item__restaurant')
        # if existing_items.exists():
        #     first_item = existing_items.first()
        #     if first_item.menu_item.restaurant_id != new_menu_item.restaurant_id:
        #         raise serializers.ValidationError(
        #             f"Cannot add items from different restaurants. "
        #             f"This cart contains items from {first_item.menu_item.restaurant.restaurant_name}. "
        #             f"Please create a new cart or clear the existing one."
        #         )

        return attrs

    def save(self, **kwargs):
        cart_id = self.context["cart_id"]
        menu_item_id = self.validated_data["menu_item_id"]
        qty = self.validated_data["qty"]

        try:
            cart_item = CartItem.objects.get(cart_id=cart_id, menu_item_id=menu_item_id)
            cart_item.qty += qty
            cart_item.save()
            self.instance = cart_item
        except CartItem.DoesNotExist:
            self.instance = CartItem.objects.create(
                cart_id=cart_id, **self.validated_data
            )
        return self.instance

    class Meta:
        model = CartItem
        fields = ["id", "menu_item_id", "qty"]


class UpdateCartItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = CartItem
        fields = ["qty"]


class OrderItemSerializer(serializers.ModelSerializer):
    menu_item = SimpleMenuSerializer()
    promotion = serializers.SerializerMethodField()

    class Meta:
        model = OrderItem
        fields = [
            "id",
            "menu_item",
            "qty",
            "unit_price",
            "original_price",
            "unit_price",
            "discount_amount",
            "promotion",
        ]

    @extend_schema_field(
        {
            "type": "object",
            "properties": {
                "id": {"type": "integer"},
                "name": {"type": "string"},
                "discount": {"type": "number"},
            },
            "nullable": True,
        }
    )
    def get_promotion(self, obj):
        """Get promotion details if applied"""
        if obj.applied_promotion:
            return {
                "id": obj.applied_promotion.id,
                "name": obj.applied_promotion.name,
                "discount": obj.applied_promotion.discount,
            }
        return None


class OrderSerializer(serializers.ModelSerializer):
    items = OrderItemSerializer(many=True)
    total_discount = serializers.SerializerMethodField()
    total_amount = serializers.SerializerMethodField()

    class Meta:
        model = Order
        fields = [
            "id",
            "customer",
            "restaurant",
            "pickup_location",
            "dropoff_location",
            "placed_at",
            "status",
            "payment_status",
            "total_price",
            "delivery_fee",
            "tax",
            "items",
            "total_discount",
            "total_amount",
        ]

    @extend_schema_field(OpenApiTypes.FLOAT)
    def get_total_discount(self, obj):
        """Calculate total discount applied to order"""
        return float(sum(item.discount_amount * item.qty for item in obj.items.all()))

    @extend_schema_field(OpenApiTypes.FLOAT)
    def get_total_amount(self, obj):
        """Calculate final amount to pay (after discounts)"""
        return float(sum(item.unit_price * item.qty for item in obj.items.all()))


class UpdateOrderSerializer(serializers.ModelSerializer):
    class Meta:
        model = Order
        fields = ["status", "payment_status"]
        extra_kwargs = {
            "status": {
                "help_text": "Order status: placed, accepted, ready, picked_up, delivered, cancelled"
            },
            "payment_status": {
                "help_text": "Payment status: pending, paid, failed, refunded"
            },
        }


class CreateOrderSerializer(serializers.Serializer):
    cart_id = serializers.UUIDField(help_text="UUID of the cart to convert to order")
    dropoff_location = serializers.JSONField(
        required=False,
        help_text="Delivery location with latitude, longitude, and address fields",
    )

    def validate_cart_id(self, cart_id):
        if not Cart.objects.filter(pk=cart_id).exists():
            raise serializers.ValidationError(
                "No active cart with the given ID was found."
            )
        if CartItem.objects.filter(cart_id=cart_id).count() == 0:
            raise serializers.ValidationError("The cart is empty.")
        return cart_id

    def save(self, **kwargs):
        with transaction.atomic():
            cart_id = self.validated_data["cart_id"]
            dropoff_location = self.validated_data.get("dropoff_location")

            customer, created = CustomerProfile.objects.get_or_create(
                user_id=self.context["user_id"]
            )

            cart_items = (
                CartItem.objects.filter(cart_id=cart_id)
                .select_related("menu_item__restaurant")
                .prefetch_related("menu_item__promotions")
                .all()
            )

            if not cart_items:
                raise serializers.ValidationError("Cart is empty.")

            restaurant = cart_items[0].menu_item.restaurant

            if dropoff_location:
                lat = float(dropoff_location["latitude"])
                lng = float(dropoff_location["longitude"])
                address = dropoff_location["address"]

                point = Point(lng, lat)

            # for item in cart_items:
            #     if item.menu_item.restaurant_id != restaurant.id:
            #         raise serializers.ValidationError(
            #             "All items in the cart must be from the same restaurant."
            #         )

            order = Order.objects.create(
                customer=customer,
                dropoff_location=(
                    point if dropoff_location else customer.current_location
                ),
                restaurant=restaurant,
                pickup_location=(
                    restaurant.location if hasattr(restaurant, "location") else None
                ),
            )

            now = timezone.now()
            order_items = []
            for item in cart_items:
                active_promos = item.menu_item.promotions.filter(
                    is_active=True, start_date__lte=now, end_date__gte=now
                )
                if active_promos.exists():
                    highest_discount = max(p.discount for p in active_promos)
                    unit_price = item.menu_item.price * Decimal(
                        str(1 - highest_discount / 100)
                    )
                else:
                    unit_price = item.menu_item.price
                order_items.append(
                    OrderItem(
                        order=order,
                        menu_item=item.menu_item,
                        qty=item.qty,
                        unit_price=unit_price,
                    )
                )

            OrderItem.objects.bulk_create(order_items)

            total_price = float(sum(oi.unit_price * oi.qty for oi in order.items.all()))

            # Update order total price
            order.total_price = total_price
            order.save(update_fields=["total_price"])

            Cart.objects.filter(id=cart_id).delete()

            return order

