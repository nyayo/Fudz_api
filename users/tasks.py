import logging

from celery import shared_task
from firebase_admin import messaging
from push_notifications.models import APNSDevice, GCMDevice, WebPushDevice

from .helpers import convert_data_to_strings
from .models import NotificationPreference, User

logger = logging.getLogger(__name__)

@shared_task
def send_fcm_notification_admin(user_id, title, body, data=None):
    """
    Send FCM notification using Firebase Admin SDK.
    Respects user notification preferences.
    """
    try:
        user = User.objects.get(id=user_id)
        
        # Check notification preferences
        try:
            prefs = NotificationPreference.objects.get(user=user)
            if not prefs.receive_push:
                logger.info(f"User {user_id} has disabled push notifications")
                return {'skipped': True, 'reason': 'Push notifications disabled by user'}
        except NotificationPreference.DoesNotExist:
            pass  # No preferences set, send notifications by default
        
        fcm_devices = GCMDevice.objects.filter(user=user, active=True)
        
        success_count = 0
        failed_tokens = []
        
        string_data = convert_data_to_strings(data) if data else {}
        
        for device in fcm_devices:
            try:
                message = messaging.Message(
                    notification=messaging.Notification(
                        title=title,
                        body=body,
                    ),
                    data=string_data or {},
                    token=device.registration_id,
                    android=messaging.AndroidConfig(
                        priority='high',
                        notification=messaging.AndroidNotification(
                            sound='default',
                            channel_id='default',
                        ),
                    ),
                )
                
                response = messaging.send(message)
                logger.info(f"FCM sent successfully: {response}")
                success_count += 1
                
            except messaging.UnregisteredError:
                logger.warning(f"Invalid token for device {device.id}, marking inactive")
                device.active = False
                device.save()
                failed_tokens.append(device.registration_id)
                
            except Exception as e:
                logger.error(f"Error sending to device {device.id}: {str(e)}")
                failed_tokens.append(device.registration_id)
        
        return {
            'success_count': success_count,
            'failed_count': len(failed_tokens),
            'failed_tokens': failed_tokens
        }
        
    except User.DoesNotExist:
        logger.error(f"User {user_id} not found")
        return {'error': 'User not found'}


@shared_task
def send_push_notification_to_user(user_id, title, body, data=None):
    """
    Send push notification to ALL device types for a user.
    Respects user notification preferences.
    """
    try:
        user = User.objects.get(id=user_id)
        
        # Check notification preferences
        try:
            prefs = NotificationPreference.objects.get(user=user)
            if not prefs.receive_push:
                logger.info(f"User {user_id} has disabled push notifications")
                return {'skipped': True, 'reason': 'Push notifications disabled by user'}
        except NotificationPreference.DoesNotExist:
            pass  # No preferences set, send notifications by default
        
        results = {}
        
        string_data = convert_data_to_strings(data) if data else {}
        
        fcm_result = send_fcm_notification_admin(user_id, title, body, data)
        results['fcm'] = fcm_result
        
        try:
            apns_devices = APNSDevice.objects.filter(user=user, active=True)
            if apns_devices.exists():
                apns_devices.send_message(
                    message=body,
                    title=title,
                    extra=string_data or {},
                    sound='default'
                )
                results['apns'] = {'success': True, 'count': apns_devices.count()}
        except Exception as e:
            results['apns'] = {'error': str(e)}
        
        try:
            web_devices = WebPushDevice.objects.filter(user=user, active=True)
            if web_devices.exists():
                web_devices.send_message(
                    message=body,
                    title=title,
                    extra=data or {}
                )
                results['web_push'] = {'success': True, 'count': web_devices.count()}
        except Exception as e:
            results['web_push'] = {'error': str(e)}
        
        logger.info(f"Notifications sent to user {user_id}: {results}")
        return results
        
    except User.DoesNotExist:
        logger.error(f"User {user_id} not found")
        return {'error': 'User not found'}
    
    
@shared_task
def send_fcm_to_multiple_users(user_ids, title, body, data=None):
    """
    Send FCM notification to multiple users
    """
    try:
        all_tokens = []
        string_data = convert_data_to_strings(data) if data else {}
        user_device_map = {}
        
        for user_id in user_ids:
            devices = GCMDevice.objects.filter(user_id=user_id, active=True)
            tokens = list(devices.values_list('registration_id', flat=True))
            all_tokens.extend(tokens)
            user_device_map[user_id] = tokens
        
        if not all_tokens:
            return {'error': 'No active devices found'}
        
        batch_size = 500
        total_success = 0
        total_failed = 0
        
        for i in range(0, len(all_tokens), batch_size):
            batch_tokens = all_tokens[i:i + batch_size]
            
            
            message = messaging.MulticastMessage(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=string_data or {},
                tokens=batch_tokens,
                android=messaging.AndroidConfig(
                    priority='high',
                ),
            )
            
            response = messaging.send_each_for_multicast(message)
            total_success += response.success_count
            total_failed += response.failure_count
            
            if response.failure_count > 0:
                for idx, resp in enumerate(response.responses):
                    if not resp.success:
                        failed_token = batch_tokens[idx]
                        if isinstance(resp.exception, messaging.UnregisteredError):
                            GCMDevice.objects.filter(
                                registration_id=failed_token
                            ).update(active=False)
        
        return {
            'success_count': total_success,
            'failed_count': total_failed,
            'total_users': len(user_ids)
        }
        
    except Exception as e:
        logger.error(f"Error in batch notification: {str(e)}")
        return {'error': str(e)}


# ============================================================
# EMAIL TASKS - Async email sending via Celery
# ============================================================

@shared_task(bind=True, max_retries=3, default_retry_delay=60)
def send_email_task(self, email_data: dict):
    """
    Send email asynchronously using Plunk API
    
    Args:
        email_data: Dictionary containing:
            - to_email: Recipient email address
            - email_subject: Email subject line
            - email_body: Plain text email body
            - email_html: HTML version of the email
            - email_type: 'html' or 'text', defaults to 'html'
    """
    from .services import PlunkEmailService
    
    try:
        result = PlunkEmailService.send_email(email_data)
        if result:
            logger.info(f"Email sent successfully to {email_data.get('to_email')}")
            return {'success': True, 'to_email': email_data.get('to_email')}
        else:
            logger.warning(f"Email sending returned False for {email_data.get('to_email')}")
            raise self.retry(exc=Exception("Email sending failed"))
    except Exception as e:
        logger.error(f"Error sending email to {email_data.get('to_email')}: {str(e)}")
        raise self.retry(exc=e)


@shared_task(bind=True, max_retries=3, default_retry_delay=60)
def send_templated_email_task(self, to_email: str, template_type: str, template_kwargs: dict):
    """
    Send templated email asynchronously
    
    Args:
        to_email: Recipient email address
        template_type: Type of email template (e.g., 'order_confirmation', 'order_delivered')
        template_kwargs: Keyword arguments for the template
    """
    from .email_templates import get_email_template
    from .services import PlunkEmailService
    
    try:
        template_data = get_email_template(template_type, **template_kwargs)
        
        email_data = {
            "to_email": to_email,
            "email_subject": template_data.get("subject"),
            "email_body": template_data.get("plain"),
            "email_html": template_data.get("html"),
            "email_type": "html",
        }
        
        result = PlunkEmailService.send_email(email_data)
        if result:
            logger.info(f"Templated email '{template_type}' sent to {to_email}")
            return {'success': True, 'to_email': to_email, 'template': template_type}
        else:
            raise self.retry(exc=Exception("Email sending failed"))
    except Exception as e:
        logger.error(f"Error sending templated email to {to_email}: {str(e)}")
        raise self.retry(exc=e)


@shared_task
def send_order_confirmation_email(order_id: int):
    """
    Send order confirmation email with product images
    """
    from django.conf import settings

    from orders.models import Order
    
    try:
        order = Order.objects.select_related(
            'customer__user', 'restaurant'
        ).prefetch_related('items__menu_item__images').get(id=order_id)
        
        customer = order.customer.user
        
        items = []
        for item in order.items.all():
            menu_item = item.menu_item
            image_url = ""
            if menu_item.images.exists():
                image_url = menu_item.images.first().image.url
            
            items.append({
                'name': menu_item.title,
                'quantity': item.qty,
                'price': f"${item.unit_price}",
                'image_url': image_url
            })
        
        template_kwargs = {
            'user_name': customer.first_name or customer.username,
            'order_id': str(order.id),
            'items': items,
            'subtotal': f"${order.total_price}",
            'delivery_fee': f"${order.delivery_fee}",
            'total': f"${order.total_price + order.delivery_fee}",
            'delivery_address': str(order.dropoff_location) if order.dropoff_location else "N/A",
            'estimated_time': "30-45 mins",
            'restaurant_name': order.restaurant.restaurant_name
        }
        
        send_templated_email_task.delay(customer.email, 'order_confirmation', template_kwargs)
        logger.info(f"Order confirmation email queued for order #{order_id}")
        return {'success': True, 'order_id': order_id}
        
    except Order.DoesNotExist:
        logger.error(f"Order {order_id} not found")
        return {'error': 'Order not found'}
    except Exception as e:
        logger.error(f"Error sending order confirmation email: {str(e)}")
        return {'error': str(e)}


@shared_task
def send_order_delivered_email(order_id: int):
    """
    Send order delivered email with product images
    """
    from django.conf import settings

    from orders.models import Order
    
    try:
        order = Order.objects.select_related(
            'customer__user', 'restaurant'
        ).prefetch_related('items__menu_item__images').get(id=order_id)
        
        customer = order.customer.user
        
        items = []
        for item in order.items.all():
            menu_item = item.menu_item
            image_url = ""
            if menu_item.images.exists():
                image_url = menu_item.images.first().image.url 
            
            items.append({
                'name': menu_item.title,
                'image_url': image_url
            })
        
        template_kwargs = {
            'user_name': customer.first_name or customer.username,
            'order_id': str(order.id),
            'restaurant_name': order.restaurant.restaurant_name,
            'items': items
        }
        
        send_templated_email_task.delay(customer.email, 'order_delivered', template_kwargs)
        logger.info(f"Order delivered email queued for order #{order_id}")
        return {'success': True, 'order_id': order_id}
        
    except Order.DoesNotExist:
        logger.error(f"Order {order_id} not found")
        return {'error': 'Order not found'}
    except Exception as e:
        logger.error(f"Error sending order delivered email: {str(e)}")
        return {'error': str(e)}


@shared_task
def send_promotion_email(promotion_id: int, user_ids: list):
    """
    Send promotion email with featured product images to multiple users
    """
    from django.conf import settings

    from restaurants.models import Promotion
    
    try:
        promotion = Promotion.objects.select_related('restaurant').get(id=promotion_id)
        
        # Get featured items from this promotion
        featured_items = []
        menu_items = promotion.menuitem_set.prefetch_related('images')[:3]
        for menu_item in menu_items:
            image_url = ""
            if menu_item.images.exists():
                image_url = menu_item.images.first().image.url
            
            original_price = f"${menu_item.price}"
            discounted_price = f"${menu_item.get_offer_price()}"
            
            featured_items.append({
                'name': menu_item.title,
                'price': discounted_price,
                'original_price': original_price if original_price != discounted_price else "",
                'image_url': image_url
            })
        
        users = User.objects.filter(id__in=user_ids)
        
        for user in users:
            template_kwargs = {
                'user_name': user.first_name or user.username,
                'promo_code': promotion.name.upper().replace(' ', ''),
                'discount_amount': f"{int(promotion.discount)}%",
                'description': promotion.description,
                'expiry_date': promotion.end_date.strftime('%B %d, %Y'),
                'featured_items': featured_items,
                'restaurant_name': promotion.restaurant.restaurant_name
            }
            
            send_templated_email_task.delay(user.email, 'promotion_discount', template_kwargs)
        
        logger.info(f"Promotion emails queued for {len(user_ids)} users")
        return {'success': True, 'users_count': len(user_ids)}
        
    except Promotion.DoesNotExist:
        logger.error(f"Promotion {promotion_id} not found")
        return {'error': 'Promotion not found'}
    except Exception as e:
        logger.error(f"Error sending promotion emails: {str(e)}")
        return {'error': str(e)}


# ============================================================
# RESTAURANT FCM NOTIFICATIONS - Notify restaurants of orders
# ============================================================

@shared_task
def notify_restaurant_new_order(order_id: int):
    """
    Send FCM notification to restaurant for new order
    """
    from orders.models import Order
    
    try:
        order = Order.objects.select_related(
            'customer__user', 'restaurant__user'
        ).prefetch_related('items__menu_item').get(id=order_id)
        
        restaurant_user = order.restaurant.user
        customer_name = f"{order.customer.user.first_name} {order.customer.user.last_name}".strip()
        
        # Get order items summary
        items_count = order.items.count()
        items_summary = ", ".join([item.menu_item.title for item in order.items.all()[:3]])
        if items_count > 3:
            items_summary += f" +{items_count - 3} more"
        
        title = "🆕 New Order!"
        body = f"New order from {customer_name or 'Customer'}\n{items_summary}\nTotal: ${order.total_price + order.delivery_fee}"
        
        data = {
            'type': 'new_order',
            'order_id': str(order.id),
            'customer_name': customer_name,
            'total': str(order.total_price + order.delivery_fee),
            'items_count': str(items_count),
        }
        
        # Send FCM notification to restaurant
        result = send_fcm_notification_admin(restaurant_user.id, title, body, data)
        logger.info(f"Restaurant notification sent for order #{order_id}: {result}")
        return result
        
    except Order.DoesNotExist:
        logger.error(f"Order {order_id} not found")
        return {'error': 'Order not found'}
    except Exception as e:
        logger.error(f"Error notifying restaurant: {str(e)}")
        return {'error': str(e)}


@shared_task
def notify_restaurant_order_status(order_id: int, old_status: str, new_status: str):
    """
    Send FCM notification to restaurant when order status changes
    """
    from orders.models import Order
    
    try:
        order = Order.objects.select_related('restaurant__user').get(id=order_id)
        restaurant_user = order.restaurant.user
        
        status_messages = {
            'accepted': ('✅ Order Accepted', f'Order #{order_id} has been confirmed'),
            'ready': ('🍽️ Order Ready', f'Order #{order_id} is ready for pickup'),
            'picked_up': ('📦 Order Picked Up', f'Order #{order_id} has been picked up by driver'),
            'delivered': ('🎉 Order Delivered', f'Order #{order_id} was successfully delivered'),
            'cancelled': ('❌ Order Cancelled', f'Order #{order_id} has been cancelled'),
        }
        
        title, body = status_messages.get(new_status, ('📋 Order Update', f'Order #{order_id} status: {new_status}'))
        
        data = {
            'type': 'order_status_update',
            'order_id': str(order_id),
            'old_status': old_status,
            'new_status': new_status,
        }
        
        result = send_fcm_notification_admin(restaurant_user.id, title, body, data)
        logger.info(f"Restaurant status notification sent for order #{order_id}: {result}")
        return result
        
    except Order.DoesNotExist:
        logger.error(f"Order {order_id} not found")
        return {'error': 'Order not found'}
    except Exception as e:
        logger.error(f"Error notifying restaurant: {str(e)}")
        return {'error': str(e)}


# ============================================================
# SMS TASKS - Async SMS sending via Celery
# ============================================================

@shared_task(bind=True, max_retries=3, default_retry_delay=60)
def send_sms_otp_task(self, phone: str, otp: str):
    """
    Send OTP via SMS asynchronously using TextBee API
    
    Args:
        phone: Phone number in international format (e.g., +254712345678)
        otp: The OTP code to send
    """
    from .services import SMSService
    
    try:
        result = SMSService.send_otp(phone, otp)
        if result:
            logger.info(f"SMS OTP sent successfully to {phone}")
            return {'success': True, 'phone': phone}
        else:
            logger.warning(f"SMS sending returned False for {phone}")
            raise self.retry(exc=Exception("SMS sending failed"))
    except Exception as e:
        logger.error(f"Error sending SMS to {phone}: {str(e)}")
        raise self.retry(exc=e)


@shared_task(bind=True, max_retries=3, default_retry_delay=60)
def send_sms_task(self, phone: str, message: str):
    """
    Send generic SMS asynchronously
    
    Args:
        phone: Phone number in international format
        message: The message to send
    """
    from .services import SMSService
    
    try:
        result = SMSService.send_bulk_sms([phone], message)
        if result.get('success'):
            logger.info(f"SMS sent successfully to {phone}")
            return {'success': True, 'phone': phone}
        else:
            logger.warning(f"SMS sending failed for {phone}: {result.get('error')}")
            raise self.retry(exc=Exception(result.get('error', 'SMS sending failed')))
    except Exception as e:
        logger.error(f"Error sending SMS to {phone}: {str(e)}")
        raise self.retry(exc=e)


@shared_task
def notify_restaurant_order_cancelled(order_id: int, reason: str = None):
    """
    Send FCM notification to restaurant when order is cancelled
    """
    from orders.models import Order
    
    try:
        order = Order.objects.select_related(
            'customer__user', 'restaurant__user'
        ).get(id=order_id)
        
        restaurant_user = order.restaurant.user
        customer_name = f"{order.customer.user.first_name} {order.customer.user.last_name}".strip()
        
        title = "❌ Order Cancelled"
        body = f"Order #{order_id} from {customer_name or 'Customer'} was cancelled"
        if reason:
            body += f"\nReason: {reason}"
        
        data = {
            'type': 'order_cancelled',
            'order_id': str(order_id),
            'reason': reason or '',
        }
        
        result = send_fcm_notification_admin(restaurant_user.id, title, body, data)
        logger.info(f"Restaurant cancellation notification sent for order #{order_id}")
        return result
        
    except Order.DoesNotExist:
        logger.error(f"Order {order_id} not found")
        return {'error': 'Order not found'}
    except Exception as e:
        logger.error(f"Error notifying restaurant: {str(e)}")
        return {'error': str(e)}
