from celery import shared_task
from django.utils import timezone
from django.core.cache import cache

from .models import Promotion, MenuItem
from users.helpers import notify_new_promotion
from users.models import User

@shared_task(bind=True, max_retries=3)
def activate_promotion(self, promotion_id):
    """
    Activate a promotion at scheduled time
    """
    try:
        promotion = Promotion.objects.get(id=promotion_id)
        
        now = timezone.now()
        if promotion.start_date <= now and not promotion.is_active:
            promotion.is_active = True
            promotion.save(update_fields=['is_active'])
            
            cache.delete(f'promotion_{promotion.id}')
            cache.delete(f'restaurant_promotions_{promotion.restaurant.id}')
            
            for menu_item in promotion.menuitem_set.all():
                cache.delete(f'menu_item_{menu_item.id}')
            
            print(f"✅ Activated promotion: {promotion.name}")
            
            try:
                users = User.objects.filter(
                    user_type='customer', 
                    is_staff=False
                ).values_list('id', flat=True)
                
                if users.exists():
                    notify_new_promotion(promotion, list(users))
                    print(f"📧 Sent notifications to {len(users)} customers")
                    
            except Exception as e:
                print(f"⚠️ Failed to send notifications: {e}")
            
            return f"Promotion '{promotion.name}' activated successfully"
        else:
            return f"Promotion '{promotion.name}' activation not needed"
            
    except Promotion.DoesNotExist:
        print(f"❌ Promotion {promotion_id} not found")
        return f"Promotion {promotion_id} not found"
    except Exception as exc:
        raise self.retry(exc=exc, countdown=60 * (2 ** self.request.retries))


@shared_task(bind=True, max_retries=3)
def deactivate_promotion(self, promotion_id):
    """
    Deactivate a promotion at scheduled time
    """
    try:
        promotion = Promotion.objects.get(id=promotion_id)
        
        now = timezone.now()
        if promotion.end_date <= now and promotion.is_active:
            promotion.is_active = False
            promotion.save(update_fields=['is_active'])
            
            cache.delete(f'promotion_{promotion.id}')
            cache.delete(f'restaurant_promotions_{promotion.restaurant.id}')
            
            for menu_item in promotion.menuitem_set.all():
                cache.delete(f'menu_item_{menu_item.id}')
            
            print(f"⏹️ Deactivated promotion: {promotion.name}")
            
            # send_promotion_ended_notification(promotion)
            
            return f"Promotion '{promotion.name}' deactivated successfully"
        else:
            return f"Promotion '{promotion.name}' deactivation not needed"
            
    except Promotion.DoesNotExist:
        print(f"❌ Promotion {promotion_id} not found")
        return f"Promotion {promotion_id} not found"
    except Exception as exc:
        raise self.retry(exc=exc, countdown=60 * (2 ** self.request.retries))


@shared_task
def check_expired_promotions():
    """
    Periodic task to check and deactivate expired promotions
    Run this every hour or daily via Celery Beat
    """
    now = timezone.now()
    expired = Promotion.objects.filter(
        is_active=True,
        end_date__lt=now
    )
    
    count = 0
    for promotion in expired:
        promotion.is_active = False
        promotion.save(update_fields=['is_active'])
        
        cache.delete(f'promotion_{promotion.id}')
        for menu_item in promotion.menuitem_set.all():
            cache.delete(f'menu_item_{menu_item.id}')
        
        count += 1
        print(f"⏹️ Auto-deactivated expired promotion: {promotion.name}")
    
    print(f"✅ Deactivated {count} expired promotions")
    return f"Deactivated {count} expired promotions"


@shared_task
def check_scheduled_promotions():
    """
    Periodic task to activate promotions that should have started
    Run this every hour via Celery Beat
    """
    now = timezone.now()
    scheduled = Promotion.objects.filter(
        is_active=False,
        start_date__lte=now,
        end_date__gte=now
    )
    
    count = 0
    for promotion in scheduled:
        promotion.is_active = True
        promotion.save(update_fields=['is_active'])
        
        cache.delete(f'promotion_{promotion.id}')
        for menu_item in promotion.menuitem_set.all():
            cache.delete(f'menu_item_{menu_item.id}')
        
        count += 1
        print(f"✅ Auto-activated scheduled promotion: {promotion.name}")
    
    print(f"✅ Activated {count} scheduled promotions")
    return f"Activated {count} scheduled promotions"


@shared_task
def send_promotion_reminders():
    """
    Send reminders for promotions ending soon (e.g., in 24 hours)
    """
    from datetime import timedelta
    
    now = timezone.now()
    ending_soon = now + timedelta(hours=24)
    
    promotions = Promotion.objects.filter(
        is_active=True,
        end_date__lte=ending_soon,
        end_date__gt=now
    )
    
    for promotion in promotions:
        print(f"⏰ Reminder: Promotion '{promotion.name}' ending soon!")
        try:
            users = User.objects.filter(
                user_type='customer', 
                is_staff=False
            ).values_list('id', flat=True)
            
            if users.exists():
                notify_new_promotion(promotion, list(users))
                print(f"📧 Sent notifications to {len(users)} customers")
                
        except Exception as e:
            print(f"⚠️ Failed to send notifications: {e}")
    
    return f"Sent reminders for {promotions.count()} promotions"