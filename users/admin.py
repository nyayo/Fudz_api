from django.contrib import admin
from django.contrib.gis.admin import GISModelAdmin
from django.db.models import Count
from django.urls import reverse
from django.utils.html import format_html, urlencode
from . import models

@admin.register(models.User)
class UserProfileAdmin(admin.ModelAdmin):
    list_display = ["full_name", "phone", "email", "user_type", "is_staff", "is_active"]
    ordering = ["first_name", "last_name"]
    list_filter = ["user_type", "is_staff", "is_active"]
    list_per_page = 10
    search_fields = ["first_name__istartswith", "last_name__istartswith", "phone__istartswith", "email__istartswith"]

    def full_name(self, user):
        return f"{user.first_name} {user.last_name}"

@admin.register(models.CustomerProfile)
class CustomerAdmin(admin.ModelAdmin):
    list_display = ["user__first_name", "user__last_name", "user__phone", "current_location", "address"]
    ordering = ["user__first_name", "user__last_name"]
    list_per_page = 10
    search_fields = ["user__first_name__istartswith", "user__last_name__istartswith"]

    def orders_count(self, customer):
        return format_html('<a href="{}">{}</a>', customer.orders_count)

    def get_queryset(self, request):
        return (
            super().get_queryset(request).annotate(orders_count=Count("orders"))
        )


@admin.register(models.CourierProfile)
class CourierAdmin(GISModelAdmin):
    list_display = [
        "courier_name",
        "user__username",
        "user__email",
        "user__phone",
        "license_number",
        "vehicle_type",
        "is_available",
        "is_approved",
        "rating",
        "current_location",
    ]
    ordering = ["user__first_name", "user__last_name"]
    list_editable = ["is_available", "is_approved"]
    list_per_page = 10
    search_fields = ["user__first_name__istartswith", "user__last_name__istartswith"]

    default_lon = 0
    default_lat = 0
    default_zoom = 2

    def courier_name(self, courier):
        return f"{courier.user.first_name} {courier.user.last_name}"


@admin.register(models.RestaurantProfile)
class RestaurantAdmin(GISModelAdmin):
    list_display = ["restaurant_name", "restaurant_owner", "business_license", "address", "location", "opening_hours", "is_approved", "is_active", "rating"]
    ordering = ["restaurant_name"]
    list_editable = ["is_approved", "is_active"]
    list_per_page = 10
    search_fields = ["restaurant_name", "address", "is_approved"]
    
    default_lon = 0
    default_lat = 0
    default_zoom = 2

    def restaurant_owner(self, restaurant):
        return restaurant.user.first_name + " " + restaurant.user.last_name

@admin.register(models.EmailVerification)
class EmailVerificationAdmin(admin.ModelAdmin):
    list_display = ["email", "otp", "is_verified", "created_at", "expires_at"]
    ordering = ["-created_at"]
    list_filter = ["is_verified"]
    list_per_page = 10

@admin.register(models.RestaurantStaffProfile)
class RestaurantStaffAdmin(GISModelAdmin):
    list_display = ["user", "restaurant", "role", "is_active"]
    ordering = ["user__first_name", "user__last_name"]
    list_editable = ["is_active"]
    list_per_page = 10
    search_fields = ["restaurant", "address", "is_verified"]

    default_lon = 0
    default_lat = 0
    default_zoom = 2

    def restaurant_owner(self, restaurant):
        return restaurant.user.first_name + " " + restaurant.user.last_name
