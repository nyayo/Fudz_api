from django.contrib import admin
from django.contrib.gis.admin import GISModelAdmin
from django.http import Http404, JsonResponse
from django.urls import path
from django.utils.html import format_html
from django.views.decorators.csrf import csrf_exempt
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
    list_display = ["id", "restaurant", "courier", "payment_status", "customer", "placed_at", "pickup_location", "dropoff_location", "status_badge"]
    default_lon = 0
    default_lat = 0
    default_zoom = 2
    
    def status_badge(self, obj):
        colors = {
            "placed": "#ffc107",   
            "accepted": "#007bff",
            "ready": "#17a2b8", 
            "picked_up": "#6f42c1", 
            "delivered": "#28a745",
            "cancelled": "#dc3545",  
        }
        color = colors.get(obj.status, "#6c757d")
        return format_html(
            f'<span style="background-color:{color}; color:white; padding:4px 8px; border-radius:5px;">{obj.status.upper()}</span>'
        )
    status_badge.short_description = "Status"


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
    
@admin.register(models.Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ("id", "event_type_colored", "order_id", "short_message", "created_at", "is_read")
    list_filter = ("event_type", "is_read", "created_at")
    search_fields = ("message", "order_id")

    def short_message(self, obj):
        return (obj.message[:70] + "...") if len(obj.message) > 70 else obj.message
    short_message.short_description = "Message"

    def event_type_colored(self, obj):
        colors = {
            "new_order": "#28a745",     # Green
            "order_update": "#007bff",  # Blue
        }
        color = colors.get(obj.event_type, "#6c757d")
        return format_html(
            f'<span style="background-color:{color}; color:white; padding:3px 8px; border-radius:5px;">{obj.get_event_type_display()}</span>'
        )
    event_type_colored.short_description = "Event Type"
    
    def get_urls(self):
        urls = super().get_urls()
        custom_urls = [
            path("mark-all-read/", self.admin_site.admin_view(self.mark_all_read), name="notifications-mark-all-read"),
            path("mark-read/<int:pk>/", self.admin_site.admin_view(self.mark_read), name="notifications-mark-read"),
            path("unread/", self.admin_site.admin_view(self.get_unread_notifications), name="notifications-unread"),
        ]
        return custom_urls + urls

    @csrf_exempt
    def mark_all_read(self, request):
        models.Notification.objects.filter(is_read=False).update(is_read=True)
        return JsonResponse({"success": True})
    
    @csrf_exempt
    def mark_read(self, request, pk):
        try:
            notif = models.Notification.objects.get(id=pk)
            notif.is_read = True
            notif.save()
            return JsonResponse({"success": True})
        except models.Notification.DoesNotExist:
            raise Http404

    @csrf_exempt
    def get_unread_notifications(self, request):
        notifications = models.Notification.objects.filter(is_read=False).order_by('-created_at')[:20]
        
        data = {
            'notifications': [
                {
                    'type': notif.event_type,
                    'message': notif.message,
                    'id': notif.id,
                }
                for notif in notifications
            ]
        }
        
        return JsonResponse(data)