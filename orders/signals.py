from django.db.models.signals import post_save
from django.dispatch import receiver
from django.core.mail import send_mail
from django.contrib.auth import get_user_model
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer

from .models import Notification, Order
from users.models import User
from users.services import send_normal_email
from users.helpers import send_order_notification

# User = get_user_model()


@receiver(post_save, sender=Order)
def order_notification(sender, instance, created, **kwargs):
    """Notify admins when order is created or updated"""
    admins = User.objects.filter(is_staff=True, email__isnull=False)

    if created:
        subject = f"🆕 New Order #{instance.id}"
        body = f"A new order has been placed by {instance.customer.user.first_name} {instance.customer.user.last_name} for {instance.restaurant.restaurant_name}."
        event_type = "new_order"
    else:
        subject = f"🔄 Order #{instance.id} Status Updated"
        body = f"Order #{instance.id} status changed to: {instance.status.upper()}."
        event_type = "order_update"
        
    notification = Notification.objects.create(
        event_type=event_type,
        message=body,
        order_id=instance.id
    )
    
    # data={
    #     'email_body':body, 
    #     'email_subject':subject, 
    #     'to_email':[a.email for a in admins],
    # }
    
    # send_normal_email(data)

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

    if created:
        title = "Placed"
        subject = f"🆕 New Order #{instance.id}"
        body = f"Your order has been placed."
        event_type = "new_order"
    else:
        if instance.status == "accepted":
            title = "Accepted"
            subject = f"🔄 Order #{instance.id} Status Updated"
            body = f"Your order #{instance.id} has been {instance.status.capitalize()}."
            event_type = "order_update"
        elif instance.status == "delivered":
            title = "Delivered"
            subject = f"✅ Order #{instance.id} Delivered"
            body = f"Your order #{instance.id} has been {instance.status.capitalize()}."
            event_type = "order_update"
        else:
            return None

    Notification.objects.create(
        event_type=event_type,
        message=body,
        order_id=instance.id
    )

    send_order_notification(customer, title, instance)

    # data={
    #     'email_body':body, 
    #     'email_subject':subject, 
    #     'to_email':[a.email for a in admins],
    # }
    
    # send_normal_email(data)

    send_mail(
        subject,
        body,
        "no-reply@foodapp.com",
        [customer.email],
        fail_silently=True,
    )