from django.db.models.signals import post_save
from django.dispatch import receiver
from django.utils import timezone

from .models import Promotion
from .tasks import activate_promotion, deactivate_promotion


def send_promotion_created_notification(promotion):
    """
    Send notification when a promotion is created and active
    """
    from users.helpers import notify_new_promotion
    from users.models import User

    try:
        users = User.objects.filter(user_type="customer", is_staff=False).values_list(
            "id", flat=True
        )

        if users.exists():
            notify_new_promotion(promotion, list(users))
            print(
                f"📧 Sent promotion created email notifications to {len(users)} customers"
            )

    except Exception as e:
        print(f"⚠️ Failed to send promotion created notifications: {e}")


@receiver(post_save, sender=Promotion)
def schedule_promotion_status_change(sender, instance, created, **kwargs):
    """
    Schedule automatic activation/deactivation of promotions
    """
    now = timezone.now()

    if instance.start_date > now:
        eta = instance.start_date

        activate_promotion.apply_async(
            args=[instance.id],
            eta=eta,
            task_id=f"activate_promotion_{instance.id}",
        )
        print(f"📅 Scheduled activation for '{instance.name}' at {instance.start_date}")

    if instance.end_date > now and instance.is_active:
        eta = instance.end_date

        deactivate_promotion.apply_async(
            args=[instance.id],
            eta=eta,
            task_id=f"deactivate_promotion_{instance.id}",
        )
        print(f"📅 Scheduled deactivation for '{instance.name}' at {instance.end_date}")

    if instance.end_date <= now and instance.is_active:
        deactivate_promotion.delay(instance.id)
        print(f"⚡ Immediately deactivating expired promotion '{instance.name}'")

    if (
        created
        and instance.is_active
        and instance.start_date <= now <= instance.end_date
    ):
        send_promotion_created_notification(instance)
        print(f"📢 Sent email for newly created promotion '{instance.name}'")
