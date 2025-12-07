import random
import string

from django.contrib.auth.models import AbstractUser, PermissionsMixin
from django.contrib.gis.db import models as gis_models
from django.contrib.gis.geos import Point
from django.core.validators import RegexValidator
from django.db import models
from django.utils import timezone
from rest_framework_simplejwt.tokens import RefreshToken

from .managers import UserManager

AUTH_PROVIDERS = {
    "email": "email",
    "google": "google",
    "github": "github",
    "linkedin": "linkedin",
}


class User(AbstractUser, PermissionsMixin):
    USER_TYPES = (
        ("customer", "Customer"),
        ("courier", "Courier"),
        ("restaurant", "Restaurant"),
        ("restaurant_staff", "Restaurant Staff"),
    )

    phone_regex = RegexValidator(
        regex=r"^\+?[1-9]\d{1,14}$",
        message="Phone number must be in format: '+999999999'. Up to 15 digits allowed.",
    )
    phone = models.CharField(
        validators=[phone_regex],
        max_length=17,
        blank=True,
        null=True,
        help_text="Phone number in international format",
    )
    email = models.EmailField(unique=True)
    user_type = models.CharField(
        max_length=20, choices=USER_TYPES, db_index=True
    )

    is_verified = models.BooleanField(default=False)
    auth_provider = models.CharField(
        max_length=50,
        blank=False,
        null=False,
        default=AUTH_PROVIDERS.get("email"),
    )
    username = models.CharField(max_length=150, unique=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = ["user_type", "first_name", "last_name"]

    objects = UserManager()

    def save(self, *args, **kwargs):
        if not self.username:
            base_username = self.email.split("@")[0]

            if self.user_type == "customer":
                self.username = f"customer_{base_username}"
            elif self.user_type == "courier":
                self.username = f"courier_{base_username}"
            else:
                self.username = f"restaurant_{base_username}"

            counter = 1
            original_username = self.username
            while (
                User.objects.filter(username=self.username)
                .exclude(id=self.id)
                .exists()
            ):
                self.username = f"{original_username}_{counter}"
                counter += 1

        super().save(*args, **kwargs)

    def tokens(self):
        refresh = RefreshToken.for_user(self)
        return {"refresh": str(refresh), "access": str(refresh.access_token)}

    def __str__(self):
        return f"{self.first_name} {self.last_name} - {self.get_user_type_display()}"


class EmailVerification(models.Model):
    email = models.EmailField()
    otp = models.CharField(max_length=6)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    is_verified = models.BooleanField(default=False)

    def __str__(self):
        return f"{self.email} - {self.otp}"

    def is_expired(self):
        return timezone.now() > self.expires_at

    def generate_otp(self):
        self.otp = "".join(random.choices(string.digits, k=6))
        self.expires_at = timezone.now() + timezone.timedelta(minutes=10)
        self.save()


class CustomerProfile(models.Model):
    user = models.OneToOneField(
        User, on_delete=models.CASCADE, related_name="customer_profile"
    )
    current_location = gis_models.PointField(
        geography=True, null=True, blank=True
    )
    date_of_birth = models.DateField(blank=True, null=True)
    address = models.ForeignKey(
        "Address", on_delete=models.SET_NULL, null=True, blank=True
    )
    order_stats = models.JSONField(default=dict, blank=True)

    def __str__(self):
        return f"{self.user.username}"


class CourierProfile(models.Model):
    VEHICLE_CHOICES = (
        ("bike", "Bike"),
        ("motorcycle", "Motorcycle"),
        ("car", "Car"),
    )

    user = models.OneToOneField(
        User, on_delete=models.CASCADE, related_name="courier_profile"
    )
    vehicle_type = models.CharField(max_length=20, choices=VEHICLE_CHOICES)
    license_number = models.CharField(max_length=50, blank=True)
    is_available = models.BooleanField(default=True, db_index=True)
    is_approved = models.BooleanField(default=False, db_index=True)
    current_location = gis_models.PointField(
        geography=True, null=True, blank=True
    )
    performance_stats = models.JSONField(default=dict, blank=True)
    rating = models.DecimalField(
        max_digits=3, decimal_places=2, default=0.0, db_index=True
    )
    total_deliveries = models.PositiveIntegerField(default=0, db_index=True)
    earnings_balance = models.DecimalField(
        max_digits=10, decimal_places=2, default=0.00
    )

    def __str__(self):
        return f"{self.user.username}"


class RestaurantProfile(models.Model):
    user = models.OneToOneField(
        User, on_delete=models.CASCADE, related_name="restaurant_profile"
    )
    restaurant_name = models.CharField(max_length=100)
    business_license = models.CharField(max_length=100, unique=True)
    image = models.ImageField(
        upload_to="images/restaurant_images/",
        null=True,
        blank=True,
        help_text="Restaurant profile image",
    )
    address = models.TextField()
    location = gis_models.PointField(
        geography=True, null=True, blank=True, default=Point(0, 0)
    )
    opening_hours = models.JSONField(default=dict)
    rating = models.DecimalField(
        max_digits=3, decimal_places=2, default=0.0, db_index=True
    )
    is_approved = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return f"{self.restaurant_name}"


class RestaurantStaffProfile(models.Model):
    ROLE_CHOICES = (
        ("manager", "Manager"),
        ("waiter", "Waiter"),
        ("cashier", "Cashier"),
    )

    user = models.OneToOneField(
        User, on_delete=models.CASCADE, related_name="restaurant_staff_profile"
    )
    restaurant = models.ForeignKey(
        RestaurantProfile, on_delete=models.CASCADE, related_name="staff"
    )
    role = models.CharField(max_length=50, choices=ROLE_CHOICES)
    is_active = models.BooleanField(default=True)
    date_joined = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.first_name} - {self.role} @ {self.restaurant.restaurant_name}"


class Address(models.Model):
    user = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name="addresses"
    )
    label = models.CharField(max_length=100)
    street = models.CharField(max_length=255)
    city = models.CharField(max_length=100)
    phone = models.CharField(max_length=20)
    location = gis_models.PointField(geography=True)

    def __str__(self):
        return f"{self.label} ({self.user.username})"


class NotificationPreference(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    receive_push = models.BooleanField(default=True)
    receive_email = models.BooleanField(default=True)

    class Meta:
        db_table = "notification_preferences"

