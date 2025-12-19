from uuid import uuid4

from django.contrib.gis.db import models as gis_models
from django.db import models
from django.urls import reverse

from restaurants.models import MenuItem
from users.models import CourierProfile, CustomerProfile, RestaurantProfile


class Cart(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid4)
    created_at = models.DateTimeField(auto_now_add=True)


class CartItem(models.Model):
    cart = models.ForeignKey(Cart, on_delete=models.CASCADE, related_name="items")
    menu_item = models.ForeignKey(MenuItem, on_delete=models.CASCADE)
    qty = models.PositiveIntegerField(default=1)

    class Meta:
        unique_together = [["cart", "menu_item"]]


class Order(models.Model):
    STATUS_CHOICES = [
        ("placed", "Placed"),
        ("accepted", "Accepted"),
        ("ready", "Ready for pickup"),
        ("picked_up", "Picked up"),
        ("delivered", "Delivered"),
        ("cancelled", "Cancelled"),
    ]
    customer = models.ForeignKey(
        CustomerProfile, on_delete=models.CASCADE, related_name="orders"
    )
    restaurant = models.ForeignKey(
        RestaurantProfile, on_delete=models.CASCADE, related_name="orders"
    )
    courier = models.ForeignKey(
        CourierProfile,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="orders",
    )
    pickup_location = gis_models.PointField(geography=True, null=True, blank=True)
    dropoff_location = gis_models.PointField(geography=True, null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="placed")
    payment_status = models.CharField(max_length=20, default="pending")
    placed_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Order {self.id} - {self.status}"


class OrderItem(models.Model):
    order = models.ForeignKey(Order, on_delete=models.PROTECT, related_name="items")
    menu_item = models.ForeignKey(
        MenuItem, on_delete=models.PROTECT, related_name="orderitems"
    )
    qty = models.PositiveSmallIntegerField()
    unit_price = models.DecimalField(max_digits=10, decimal_places=2)
    original_price = models.DecimalField(
        max_digits=10, 
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Original menu item price"
    )
    applied_promotion = models.ForeignKey(
        'restaurants.Promotion',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='order_items',
        help_text="Promotion applied at time of order"
    )
    
    discount_amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0,
        help_text="Total discount amount for this item"
    )
    
    class Meta:
        ordering = ['id']
    
    def __str__(self):
        return f"{self.qty} x {self.menu_item.title}"
    
    @property
    def total_price(self):
        """Total price for this order item"""
        return self.unit_price * self.qty
    
    @property
    def total_savings(self):
        """Total amount saved on this order item"""
        return self.discount_amount * self.qty


class Notification(models.Model):
    EVENT_CHOICES = [
        ("new_order", "New Order"),
        ("order_update", "Order Update"),
    ]

    event_type = models.CharField(max_length=20, choices=EVENT_CHOICES)
    message = models.TextField()
    order_id = models.PositiveIntegerField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    is_read = models.BooleanField(default=False)

    def get_redirect_url(self):
        if self.order_id:
            return reverse("admin:orders_order_change", args=[self.order_id])
        return "#"

    def mark_as_read(self):
        self.is_read = True
        self.save(update_fields=["is_read"])

    def __str__(self):
        return f"{self.get_event_type_display()} - Order #{self.order_id}"

    class Meta:
        ordering = ["-created_at"]
