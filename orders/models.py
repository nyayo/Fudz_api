from django.db import models
from django.contrib.gis.db import models as gis_models
from uuid import uuid4

from restaurants.models import MenuItem
from users.models import CustomerProfile, CourierProfile, RestaurantProfile

class Cart(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid4)
    created_at = models.DateTimeField(auto_now_add=True)


class CartItem(models.Model):
    cart = models.ForeignKey(Cart, on_delete=models.CASCADE, related_name="items")
    menu_item = models.ForeignKey(MenuItem, on_delete=models.CASCADE)
    qty = models.PositiveIntegerField(default=1)
    
    class Meta:
        unique_together = [['cart', 'menu_item']]


class Order(models.Model):
    STATUS_CHOICES = [
        ("placed", "Placed"),
        ("preparing", "Preparing"),
        ("accepted", "Accepted"),
        ("ready", "Ready for pickup"),
        ("picked_up", "Picked up"),
        ("delivering", "Delivering"),
        ("delivered", "Delivered"),
        ("cancelled", "Cancelled"),
    ]
    customer = models.ForeignKey(CustomerProfile, on_delete=models.CASCADE, related_name="orders")
    restaurant = models.ForeignKey(RestaurantProfile, on_delete=models.CASCADE, related_name="orders")
    courier = models.ForeignKey(CourierProfile, on_delete=models.SET_NULL, null=True, blank=True, related_name="orders")
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
    menu_item = models.ForeignKey(MenuItem, on_delete=models.PROTECT, related_name="orderitems")
    qty = models.PositiveSmallIntegerField()
    unit_price = models.DecimalField(max_digits=10, decimal_places=2)
