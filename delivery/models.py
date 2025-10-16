from django.db import models
from django.contrib.gis.db import models as gis_models
from django.utils import timezone
from users.models import CourierProfile
from orders.models import Order

class DeliveryRequest(models.Model):
    STATUS_CHOICES = [
        ("pending", "Pending"),
        ("assigned", "Assigned"),
        ("accepted", "Accepted"),
        ("declined", "Declined"),
        ("picked_up", "Picked Up"),
        ("delivered", "Delivered"),
        ("cancelled", "Cancelled"),
    ]

    order = models.OneToOneField(Order, on_delete=models.CASCADE, related_name="delivery_request")
    courier = models.ForeignKey(CourierProfile, on_delete=models.SET_NULL, null=True, blank=True, related_name="deliveries")
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="pending")

    pickup_location = gis_models.PointField(geography=True, null=True, blank=True)
    dropoff_location = gis_models.PointField(geography=True, null=True, blank=True)

    assigned_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Delivery for Order #{self.order.id} - {self.status}"

    def assign_to(self, courier):
        self.courier = courier
        self.status = "assigned"
        self.assigned_at = timezone.now()
        self.save()

    def mark_status(self, status):
        self.status = status
        self.save()
    
    
    
class DeliveryTracking(models.Model):
    order = models.OneToOneField(Order, on_delete=models.CASCADE, related_name='tracking')
    courier = models.ForeignKey(CourierProfile, on_delete=models.CASCADE)
    current_location = gis_models.PointField(geography=True)
    last_updated = models.DateTimeField(auto_now=True)


class CourierEarnings(models.Model):
    courier = models.ForeignKey(CourierProfile, on_delete=models.CASCADE, related_name='earnings')
    order = models.ForeignKey(Order, on_delete=models.CASCADE)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    created_at = models.DateTimeField(auto_now_add=True)
