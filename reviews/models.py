from django.db import models
from django.core.validators import MinValueValidator, MaxValueValidator

from users.models import CustomerProfile, RestaurantProfile

class RestaurantReview(models.Model):
    customer = models.ForeignKey(CustomerProfile, on_delete=models.CASCADE, related_name="reviews")
    restaurant = models.ForeignKey(RestaurantProfile, on_delete=models.CASCADE, related_name="reviews")
    rating = models.PositiveSmallIntegerField(validators=[MinValueValidator(1), MaxValueValidator(5)])
    comment = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ["customer", "restaurant"]
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.restaurant.restaurant_name} - {self.rating}⭐ by {self.customer.user.first_name} {self.customer.user.last_name}"
