# Django Backend Files for Push Notifications (Updated for Global Topics)

These files enable automatic notifications for both specific order updates and global promotion broadcasts.

---

## 1. orders/signals.py
Update to use the correct status mappings and notification helper.

```python
from django.db.models.signals import post_save, pre_save
from django.dispatch import receiver
from .models import Order
from users.helpers import send_order_notification

@receiver(pre_save, sender=Order)
def store_previous_status(sender, instance, **kwargs):
    if instance.pk:
        try:
            instance._previous_status = Order.objects.get(pk=instance.pk).status
        except Order.DoesNotExist:
            instance._previous_status = None

@receiver(post_save, sender=Order)
def order_status_changed(sender, instance, created, **kwargs):
    if created:
        send_order_notification(instance.customer, "Order Placed", instance)
        return
    
    previous_status = getattr(instance, '_previous_status', None)
    if previous_status and previous_status != instance.status:
        status_messages = {
            'accepted': 'Order Accepted',
            'preparing': 'Food is being Prepared',
            'ready': 'Ready for Pickup',
            'out_for_delivery': 'Out for Delivery',
            'delivered': 'Enjoy your meal!',
            'cancelled': 'Order Cancelled',
        }
        title = status_messages.get(instance.status, "Order Status Update")
        send_order_notification(instance.customer, title, instance)
```

---

## 2. restaurants/tasks.py (Integration with Activation)

Since you already have tasks for **activation**, the best place to send the notification is inside the task that makes the promotion "live." This ensures the push notification lands exactly when the promotion starts.

**In your `activate_promotion` task (or similar), add this:**

```python
@shared_task
def activate_promotion(promotion_id):
    promotion = Promotion.objects.get(id=promotion_id)
    promotion.is_active = True
    promotion.save()

    # ADD THIS LINE HERE:
    from users.helpers import notify_topic_promotion
    notify_topic_promotion(promotion)
```

---

## 3. restaurants/signals.py (Immediate Promotions)

If you create a promotion that is **already active** (starts immediately), you should also trigger the notification in the signal:

```python
from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import Promotion
from users.helpers import notify_topic_promotion

@receiver(post_save, sender=Promotion)
def promotion_immediate_notify(sender, instance, created, **kwargs):
    # Only notify here if it's new and ALREADY active (manual creation)
    # The scheduled activation task will handle the others.
    if created and instance.is_active:
        notify_topic_promotion(instance)
```

---

## 4. users/tasks.py (REPLACE ENTIRE FILE)

Include these tasks for sending the actual messages:

```python
from celery import shared_task
from firebase_admin import messaging
from push_notifications.models import GCMDevice
from users.helpers import convert_data_to_strings

@shared_task
def send_push_notification_to_user(user_id, title, message, data=None):
    """Sends to a specific user using their individual device tokens"""
    devices = GCMDevice.objects.filter(user_id=user_id, active=True)
    if not devices.exists(): return
    
    string_data = convert_data_to_strings(data or {})
    string_data.update({'title': title, 'body': message})
    
    for device in devices:
        try:
            fcm_message = messaging.Message(
                notification=messaging.Notification(title=title, body=message),
                data=string_data,
                token=device.registration_id,
                android=messaging.AndroidConfig(
                    priority='high',
                    notification=messaging.AndroidNotification(
                        click_action='FLUTTER_NOTIFICATION_CLICK',
                        channel_id='order_notifications_v1', # MATCHES FLUTTER
                    ),
                ),
            )
            messaging.send(fcm_message)
        except Exception:
            pass

@shared_task
def send_fcm_to_topic(topic, title, message, data=None):
    """Broadcasts to ALL users subscribed to a topic (e.g., 'promotions')"""
    string_data = convert_data_to_strings(data or {})
    string_data.update({'title': title, 'body': message})
    
    try:
        fcm_message = messaging.Message(
            notification=messaging.Notification(title=title, body=message),
            data=string_data,
            topic=topic,
            android=messaging.AndroidConfig(
                priority='high',
                notification=messaging.AndroidNotification(
                    click_action='FLUTTER_NOTIFICATION_CLICK',
                    channel_id='promo_notifications_v2', # MATCHES FLUTTER
                ),
            ),
        )
        messaging.send(fcm_message)
        return f"Successfully sent to topic: {topic}"
    except Exception as e:
        return f"Error sending to topic: {e}"
```

---

## 5. users/helpers.py (Summary)
Ensure you have these helper functions:

```python
def notify_topic_promotion(promotion):
    from .tasks import send_fcm_to_topic
    send_fcm_to_topic.delay(
        'promotions',
        "New Promotion! 🎁",
        f"{promotion.name}: {promotion.description}",
        {
            'type': 'promotion',
            'promotion_id': str(promotion.id),
            'restaurant_id': str(promotion.restaurant.id)
        }
    )

def send_order_notification(customer, title, order):
    if not customer: return
    from .tasks import send_push_notification_to_user
    send_push_notification_to_user.delay(
        customer.user_id,
        title,
        f"Your order #{order.id} is {title.lower()}",
        {
            'type': 'order_update',
            'order_id': str(order.id)
        }
    )
```
```

---

## Deployment Steps

1. Add the two new signal files (`orders/signals.py` and `restaurants/signals.py`)
2. Update the `apps.py` files to import signals
3. Replace `users/tasks.py` with the updated version
4. Restart your Django server and Celery worker
5. Test by changing an order status in Django admin

**Note:** Make sure your Order model has a `customer` field that references the User who placed the order. Adjust the signal code if your field name is different (e.g., `user` instead of `customer`).
