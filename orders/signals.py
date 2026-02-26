from django.db.models.signals import post_save
from django.dispatch import receiver
from django.core.mail import send_mail
from django.contrib.auth import get_user_model
from django.db import transaction
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer

from .models import Notification, Order
from users.models import User
from users.services import send_normal_email
from users.helpers import send_order_notification
from users.tasks import (
    send_order_confirmation_email,
    send_order_delivered_email,
    notify_restaurant_new_order,
    notify_restaurant_order_status,
)

# User = get_user_model()


@receiver(post_save, sender=Order)
def order_notification(sender, instance, created, **kwargs):
    """Notify admins and restaurants when order is created or updated"""
    admins = User.objects.filter(is_staff=True, email__isnull=False)
    order_id = instance.id

    if created:
        subject = f"🆕 New Order #{instance.id}"
        body = f"A new order has been placed by {instance.customer.user.first_name} {instance.customer.user.last_name} for {instance.restaurant.restaurant_name}."
        event_type = "new_order"
        
        # Delay Celery tasks until after transaction commits
        transaction.on_commit(lambda: send_order_confirmation_email.delay(order_id))
        transaction.on_commit(lambda: notify_restaurant_new_order.delay(order_id))
    else:
        subject = f"🔄 Order #{instance.id} Status Updated"
        body = f"Order #{instance.id} status changed to: {instance.status.upper()}."
        event_type = "order_update"
        
    notification = Notification.objects.create(
        event_type=event_type,
        message=body,
        order_id=instance.id
    )

    send_mail(
        subject,
        body,
        "no-reply@foodapp.com",
        [a.email for a in admins],
        fail_silently=True,
    )

    channel_layer = get_channel_layer()
    async_to_sync(channel_layer.group_send)(
        "admin_notifications",
        {
            "type": "admin_notification",
            "event_type": event_type,
            "notification_id": notification.id,
            "order_id": instance.id,
            "customer": instance.customer.user.username,
            "restaurant": instance.restaurant.restaurant_name,
            "status": instance.status,
            "message": body,
            "redirect_url": notification.get_redirect_url(),
        },
    )


@receiver(post_save, sender=Order)
def customer_order_notification(sender, instance, created, **kwargs):
    """Notify Customers when order is updated"""
    customer = instance.customer.user
    order_id = instance.id
    status = instance.status

    if created:
        title = "Placed"
        subject = f"🆕 New Order #{instance.id}"
        body = f"Your order has been placed."
        event_type = "new_order"
    else:
        if status == "accepted":
            title = "Accepted"
            subject = f"🔄 Order #{instance.id} Status Updated"
            body = f"Your order #{instance.id} has been {status.capitalize()}."
            event_type = "order_update"
            
            # Delay until transaction commits
            transaction.on_commit(lambda: notify_restaurant_order_status.delay(order_id, "placed", "accepted"))
            
        elif status == "delivered":
            title = "Delivered"
            subject = f"✅ Order #{instance.id} Delivered"
            body = f"Your order #{instance.id} has been {status.capitalize()}."
            event_type = "order_update"
            
            # Delay until transaction commits
            transaction.on_commit(lambda: send_order_delivered_email.delay(order_id))
            transaction.on_commit(lambda: notify_restaurant_order_status.delay(order_id, "picked_up", "delivered"))
            
        elif status == "ready":
            title = "Ready"
            subject = f"🍽️ Order #{instance.id} Ready"
            body = f"Your order #{instance.id} is ready for pickup."
            event_type = "order_update"
            
            transaction.on_commit(lambda: notify_restaurant_order_status.delay(order_id, "accepted", "ready"))
            
        elif status == "picked_up":
            title = "Picked Up"
            subject = f"📦 Order #{instance.id} Picked Up"
            body = f"Your order #{instance.id} is on the way."
            event_type = "order_update"
            
            transaction.on_commit(lambda: notify_restaurant_order_status.delay(order_id, "ready", "picked_up"))
        else:
            return None

    Notification.objects.create(
        event_type=event_type,
        message=body,
        order_id=instance.id
    )

    send_order_notification(customer, title, instance)

    send_mail(
        subject,
        body,
        "no-reply@foodapp.com",
        [customer.email],
        fail_silently=True,
    )