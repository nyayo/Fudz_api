from celery import shared_task
from celery.exceptions import MaxRetriesExceededError

from django.contrib.gis.db.models.functions import Distance
from django.contrib.gis.geos import Point
from django.utils import timezone
from django.db import transaction

from users.models import CourierProfile
from orders.models import Order
from .models import DeliveryRequest, DeliveryStatus

@shared_task(
    bind=True,
    max_retries=3,
    default_retry_delay=60,
    autoretry_for=(Exception,),
    retry_backoff=True,
    retry_backoff_max=300,
)
def auto_assign_courier(self, delivery_id):
    """Assign nearest available courier to a delivery with retry logic"""
    try:
        delivery = DeliveryRequest.objects.get(id=delivery_id)
    except DeliveryRequest.DoesNotExist:
        return "Delivery not found"

    if not delivery.pickup_location:
        return "Pickup location missing"

    couriers = CourierProfile.objects.filter(is_available=True, current_location__isnull=False)
    if not couriers.exists():
        try:
            raise self.retry(countdown=120)
        except MaxRetriesExceededError:
            return "No available couriers after retries"

    nearby = couriers.annotate(distance=Distance("current_location", delivery.pickup_location)).order_by("distance")

    nearest = nearby.first()
    if not nearest:
        return "No courier found"
    
    with transaction.atomic():
        nearest = CourierProfile.objects.select_for_update().get(id=nearest.id)
        if not nearest.is_available:
            try:
                raise self.retry(countdown=30)
            except MaxRetriesExceededError:
                return "Courier became unavailable"
            
        delivery.courier = nearest
        delivery.status = DeliveryStatus.ASSIGNED
        delivery.assigned_at = timezone.now()
        delivery.save()
        
        order = delivery.order
        order.courier = nearest
        order.save()

        nearest.is_available = False
        nearest.save()

    return f"Assigned courier {nearest.user.username} to delivery {delivery.id}"
