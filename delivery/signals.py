from decimal import Decimal

from django.db.models.signals import post_save
from django.dispatch import receiver

from .models import DeliveryRequest, CourierEarnings

@receiver(post_save, sender=DeliveryRequest)
def handle_delivery_completed(sender, instance, **kwargs):
    if instance.status == "delivered" and instance.courier:
        order = instance.order

        total_amount = sum(item.unit_price * item.qty for item in order.items.all())
        earning_amount = total_amount * Decimal("0.8")  # 80% to courier, example split

        if not CourierEarnings.objects.filter(order=order, courier=instance.courier).exists():
            CourierEarnings.objects.create(
                courier=instance.courier,
                order=order,
                amount=earning_amount
            )
            
            instance.courier.save()
