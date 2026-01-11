import logging
from celery import shared_task
from firebase_admin import messaging
from push_notifications.models import APNSDevice, GCMDevice, WebPushDevice
from .models import User
from .helpers import convert_data_to_strings

logger = logging.getLogger(__name__)

@shared_task
def send_fcm_notification_admin(user_id, title, body, data=None):
    """
    Send FCM notification using Firebase Admin SDK
    """
    try:
        user = User.objects.get(id=user_id)
        
        fcm_devices = GCMDevice.objects.filter(user=user, active=True)
        print(f"Found {fcm_devices.count()} active FCM devices for user {user_id}")
        
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
    Send push notification to ALL device types for a user
    """
    try:
        user = User.objects.get(id=user_id)
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