from django.db.models.signals import post_save
from django.dispatch import receiver
from django.utils import timezone

from .models import Promotion
from .tasks import activate_promotion, deactivate_promotion


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
        print(
            f"📅 Scheduled activation for '{instance.name}' at {instance.start_date}"
        )

    if instance.end_date > now and instance.is_active:
        eta = instance.end_date

        deactivate_promotion.apply_async(
            args=[instance.id],
            eta=eta,
            task_id=f"deactivate_promotion_{instance.id}",
        )
        print(
            f"📅 Scheduled deactivation for '{instance.name}' at {instance.end_date}"
        )

    if instance.end_date <= now and instance.is_active:
        deactivate_promotion.delay(instance.id)
        print(
            f"⚡ Immediately deactivating expired promotion '{instance.name}'"
        )
