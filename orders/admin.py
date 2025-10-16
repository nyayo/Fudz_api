from django.contrib import admin
from django.contrib.gis.admin import GISModelAdmin
from . import models

class OrderItemInline(admin.TabularInline):
    min_num = 1
    autocomplete_fields = ["menu_item"]
    model = models.OrderItem
    extra = 0


@admin.register(models.Order)
class OrderAdmin(GISModelAdmin):
    autocomplete_fields = ["customer"]
    inlines = [OrderItemInline]
    list_display = ["id", "restaurant", "courier", "payment_status", "status", "customer", "placed_at", "pickup_location", "dropoff_location"]
    default_lon = 0
    default_lat = 0
    default_zoom = 2


class CartItemInline(admin.TabularInline):
    min_num = 1
    autocomplete_fields = ["menu_item"]
    model = models.CartItem
    extra = 0


@admin.register(models.Cart)
class CartAdmin(admin.ModelAdmin):
    inlines = [CartItemInline]
    list_display = ["id", "created_at"]
    ordering = ["-created_at"]
    list_per_page = 10
    search_fields = ["id"]