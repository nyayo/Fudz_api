from django.db import transaction
from rest_framework import serializers

from restaurants.models import MenuItem, MenuItemImage
from .models import Cart, CartItem, Order, OrderItem
from users.models import CustomerProfile


class MenuItemImageSimpleSerializer(serializers.ModelSerializer):
    class Meta:
        model = MenuItemImage
        fields = ['id', 'image']


class SimpleMenuSerializer(serializers.ModelSerializer):
    images = MenuItemImageSimpleSerializer(many=True, read_only=True)

    class Meta:
        model = MenuItem
        fields = ['id', 'title', 'price', 'images']


class CartItemSerializer(serializers.ModelSerializer):
    menu_item = SimpleMenuSerializer()
    total_price = serializers.SerializerMethodField()
    
    def get_total_price(self, cart_item: CartItem):
        return cart_item.qty * cart_item.menu_item.price
    
    class Meta:
        model = CartItem
        fields = ['id', 'menu_item', 'qty', 'total_price']


class CartSerializer(serializers.ModelSerializer):
    id = serializers.UUIDField(read_only=True)
    items = CartItemSerializer(many=True, read_only=True)
    total_price = serializers.SerializerMethodField()
    restaurant_id = serializers.SerializerMethodField()
    
    def get_total_price(self, cart: Cart):
        return sum([item.qty * item.menu_item.price for item in cart.items.all()])
    
    def get_restaurant_id(self, cart: Cart):
        first_item = cart.items.first()
        if first_item and first_item.menu_item:
            return first_item.menu_item.restaurant_id
        return None
    
    class Meta:
        model = Cart
        fields = ['id', 'items', 'total_price', 'restaurant_id']


class AddCartItemSerializer(serializers.ModelSerializer):
    menu_item_id = serializers.IntegerField()
    
    def validate_menu_item_id(self, value):
        if not MenuItem.objects.filter(pk=value).exists():
            raise serializers.ValidationError("No available menu item with the given ID was found.")
        return value
    
    def validate(self, attrs):
        cart_id = self.context['cart_id']
        menu_item_id = attrs['menu_item_id']
        
        try:
            new_menu_item = MenuItem.objects.select_related('restaurant').get(pk=menu_item_id)
        except MenuItem.DoesNotExist:
            raise serializers.ValidationError("Menu item not found.")

        existing_items = CartItem.objects.filter(cart_id=cart_id).select_related('menu_item__restaurant')
        if existing_items.exists():
            first_item = existing_items.first()
            if first_item.menu_item.restaurant_id != new_menu_item.restaurant_id:
                raise serializers.ValidationError(
                    f"Cannot add items from different restaurants. "
                    f"This cart contains items from {first_item.menu_item.restaurant.name}. "
                    f"Please create a new cart or clear the existing one."
                )
        
        return attrs
    
    def save(self, **kwargs):
        cart_id = self.context['cart_id']
        menu_item_id = self.validated_data['menu_item_id']
        qty = self.validated_data['qty']
        
        try:
            cart_item = CartItem.objects.get(cart_id=cart_id, menu_item_id=menu_item_id)
            cart_item.qty += qty
            cart_item.save()
            self.instance = cart_item
        except CartItem.DoesNotExist:
            self.instance = CartItem.objects.create(cart_id=cart_id, **self.validated_data)
        return self.instance
    
    class Meta:
        model = CartItem
        fields = ['id', 'menu_item_id', 'qty']


class UpdateCartItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = CartItem
        fields = ['qty']


class OrderItemSerializer(serializers.ModelSerializer):
    menu_item = SimpleMenuSerializer()
    
    class Meta:
        model = OrderItem
        fields = ['id', 'menu_item', 'qty', 'unit_price']


class OrderSerializer(serializers.ModelSerializer): 
    items = OrderItemSerializer(many=True)
    
    class Meta:
        model = Order
        fields = ['id', 'customer', 'restaurant', 'placed_at', 'status', 'payment_status', 'items']
 

class UpdateOrderSerializer(serializers.ModelSerializer):
    class Meta:
        model = Order
        fields = ['status', 'payment_status'] 
       
        
class CreateOrderSerializer(serializers.Serializer):
    cart_id = serializers.UUIDField()
    
    def validate_cart_id(self, cart_id):
        if not Cart.objects.filter(pk=cart_id).exists():
            raise serializers.ValidationError("No active cart with the given ID was found.")
        if CartItem.objects.filter(cart_id=cart_id).count() == 0:
            raise serializers.ValidationError("The cart is empty.")
        return cart_id
    
    def save(self, **kwargs):
        with transaction.atomic():
            cart_id = self.validated_data['cart_id']
            
            customer, created = CustomerProfile.objects.get_or_create(
                user_id=self.context['user_id']
            )

            cart_items = CartItem.objects.filter(cart_id=cart_id).select_related('menu_item__restaurant').all()
            
            if not cart_items:
                raise serializers.ValidationError("Cart is empty.")
 
            restaurant = cart_items[0].menu_item.restaurant

            for item in cart_items:
                if item.menu_item.restaurant_id != restaurant.id:
                    raise serializers.ValidationError(
                        "All items in the cart must be from the same restaurant."
                    )

            order = Order.objects.create(
                customer=customer,
                restaurant=restaurant,
                pickup_location=restaurant.location if hasattr(restaurant, 'location') else None
            )
            
            order_items = [
                OrderItem(
                    order=order,
                    menu_item=item.menu_item,
                    qty=item.qty,
                    unit_price=item.menu_item.price
                ) for item in cart_items
            ]
            
            OrderItem.objects.bulk_create(order_items)

            Cart.objects.filter(id=cart_id).delete()
            
            return order