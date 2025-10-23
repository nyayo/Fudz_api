from django.contrib import admin
from django.contrib.gis.admin import GISModelAdmin
from .models import DeliveryRequest, DeliveryTracking, CourierEarnings


@admin.register(DeliveryRequest)
class DeliveryRequestAdmin(GISModelAdmin):
	list_display = ["id", "order", "courier", "status", "pickup_location", "dropoff_location", "assigned_at", "updated_at"]
	readonly_fields = ["assigned_at", "updated_at"]
	default_lon = 0
	default_lat = 0
	default_zoom = 2


@admin.register(DeliveryTracking)
class DeliveryTrackingAdmin(GISModelAdmin):
	list_display = ["id", "delivery", "courier","current_location", "last_updated"]
	readonly_fields = ["last_updated"]
	default_lon = 0
	default_lat = 0
	default_zoom = 2
 
@admin.register(CourierEarnings)
class CourierEarningsAdmin(GISModelAdmin):
	list_display = ["id", "courier", "amount", "commission_rate", "created_at"]
	readonly_fields = ["created_at"]
	default_lon = 0
	default_lat = 0
	default_zoom = 2