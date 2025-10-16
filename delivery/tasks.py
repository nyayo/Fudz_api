from celery import shared_task

from django.contrib.gis.db.models.functions import Distance
from django.contrib.gis.geos import Point
from django.utils import timezone

from users.models import CourierProfile
from orders.models import Order
from .models import DeliveryRequest

@shared_task
def auto_assign_courier(delivery_id):
    """Assign nearest available courier to a delivery"""
    try:
        delivery = DeliveryRequest.objects.get(id=delivery_id)
    except DeliveryRequest.DoesNotExist:
        return "Delivery not found"

    if not delivery.pickup_location:
        return "Pickup location missing"

    couriers = CourierProfile.objects.filter(is_available=True, current_location__isnull=False)
    if not couriers.exists():
        return "No available couriers"

    nearby = couriers.annotate(distance=Distance("current_location", delivery.pickup_location)).order_by("distance")

    nearest = nearby.first()
    if not nearest:
        return "No courier found"
    
    delivery.courier = nearest
    delivery.status = "assigned"
    delivery.assigned_at = timezone.now()
    delivery.save()
    
    order = delivery.order
    order.courier = nearest
    order.save()

    nearest.is_available = False
    nearest.save()

    # (Optional) Send notification
    # send_courier_notification(nearest.user, f"New delivery assigned (#{delivery.id})")

    return f"Assigned courier {nearest.user.username} to delivery {delivery.id}"
