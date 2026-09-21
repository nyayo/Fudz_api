from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver
from django.db.models import Avg

from .models import RestaurantReview


@receiver(post_save, sender=RestaurantReview)
@receiver(post_delete, sender=RestaurantReview)
def update_restaurant_rating(sender, instance, **kwargs):
    """Update restaurant average rating when a review is saved or deleted."""
    restaurant = instance.restaurant
    avg = restaurant.reviews.aggregate(avg_rating=Avg('rating'))['avg_rating']
    restaurant.rating = round(avg, 2) if avg else 0.0
    restaurant.save(update_fields=['rating'])
