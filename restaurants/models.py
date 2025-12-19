from django.core.validators import MinValueValidator
from decimal import Decimal
from django.db import models

from users.models import RestaurantProfile

from .validators import validate_file_size


class Promotion(models.Model):
    restaurant = models.ForeignKey(RestaurantProfile, on_delete=models.CASCADE, related_name="promotions")
    name = models.CharField(max_length=255)
    description = models.CharField(max_length=225)
    discount = models.FloatField(validators=[MinValueValidator(0.0)])
    start_date = models.DateTimeField()
    end_date = models.DateTimeField()
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.restaurant.restaurant_name} - {self.name}"


class MenuCategory(models.Model):
    restaurant = models.ForeignKey(RestaurantProfile, on_delete=models.CASCADE, related_name="categories")
    name = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    position = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["position", "name"]
        unique_together = ["restaurant", "name"]
        verbose_name_plural = "Menu Categories"

    def __str__(self):
        return f"{self.restaurant.restaurant_name} - {self.name}"


class MenuItem(models.Model):
    restaurant = models.ForeignKey(RestaurantProfile, on_delete=models.CASCADE, related_name="menu_items")
    category = models.ForeignKey(MenuCategory, on_delete=models.CASCADE, related_name="items")
    title = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    price = models.DecimalField(max_digits=10, decimal_places=2, validators=[MinValueValidator(0.01)])
    is_available = models.BooleanField(default=True)
    is_featured = models.BooleanField(default=False)
    prep_time_minutes = models.PositiveIntegerField(null=True, blank=True)
    allergens = models.TextField(blank=True, help_text="Comma-separated list of allergens")
    promotions = models.ManyToManyField(Promotion, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["category__position", "title"]
        unique_together = ["restaurant", "title"]

    def __str__(self):
        return f"{self.restaurant.restaurant_name} - {self.title}"

    def clean(self):
        """Ensure menu item category belongs to the same restaurant"""
        from django.core.exceptions import ValidationError

        if self.category and self.category.restaurant != self.restaurant:
            raise ValidationError("Category must belong to the same restaurant as the menu item.")

    def save(self, *args, **kwargs):
        self.full_clean()
        super().save(*args, **kwargs)
        
    def get_offer_price(self):
        """Calculate price after applying the best offer"""
        from django.utils import timezone
        now = timezone.now()
        
        active_promotions = self.promotions.filter(
            is_active=True,
            start_date__lte=now,
            end_date__gte=now
        )
        
        if not active_promotions.exists():
            return self.price
        
        best_promotion = active_promotions.order_by('-discount').first()
        discount_amount = self.price * Decimal(best_promotion.discount / 100)
        offer_price = self.price - discount_amount
        
        return round(offer_price, 2)
    
    def get_active_promotion(self):
        """Get the currently active promotion with highest discount"""
        from django.utils import timezone
        now = timezone.now()
        
        return self.promotions.filter(
            is_active=True,
            start_date__lte=now,
            end_date__gte=now
        ).order_by('-discount').first()


class MenuItemImage(models.Model):
    menu_item = models.ForeignKey(MenuItem, related_name="images", on_delete=models.CASCADE)
    image = models.ImageField(upload_to="images/menu_items/")
    alt_text = models.CharField(max_length=255, blank=True)


class MenuCategoryImage(models.Model):
    category = models.ForeignKey(MenuCategory, related_name="category_image", on_delete=models.CASCADE)
    image = models.ImageField(upload_to="images/menu_categories/", validators=[validate_file_size])
    alt_text = models.CharField(max_length=255, blank=True)
