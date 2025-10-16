from django.contrib import admin
from django.contrib.gis.admin import GISModelAdmin
from .models import DeliveryRequest


@admin.register(DeliveryRequest)
class DeliveryRequestAdmin(GISModelAdmin):
	list_display = ["id", "order", "courier", "status", "pickup_location", "dropoff_location", "assigned_at", "updated_at"]
	readonly_fields = ["assigned_at", "updated_at"]
	default_lon = 0
	default_lat = 0
	default_zoom = 2
