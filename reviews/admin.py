from django.contrib import admin
from django.utils.html import format_html
from .models import RestaurantReview


@admin.register(RestaurantReview)
class RestaurantReviewAdmin(admin.ModelAdmin):
    list_display = (
        'get_restaurant_name',
        'get_customer_name',
        'get_rating_stars',
        'rating',
        'get_comment_preview',
        'created_at'
    )
    list_filter = (
        'rating',
        'created_at',
        'restaurant'
    )
    search_fields = (
        'customer__user__username',
        'customer__user__email',
        'customer__user__first_name',
        'customer__user__last_name',
        'restaurant__restaurant_name',
        'comment'
    )
    readonly_fields = ('created_at', 'get_rating_stars')
    autocomplete_fields = ['customer', 'restaurant']
    date_hierarchy = 'created_at'
    
    fieldsets = (
        ('Review Information', {
            'fields': ('customer', 'restaurant', 'rating', 'get_rating_stars')
        }),
        ('Review Content', {
            'fields': ('comment',)
        }),
        ('Metadata', {
            'fields': ('created_at',),
            'classes': ('collapse',)
        })
    )
    
    def get_restaurant_name(self, obj):
        return obj.restaurant.restaurant_name
    get_restaurant_name.short_description = 'Restaurant'
    get_restaurant_name.admin_order_field = 'restaurant__restaurant_name'
    
    def get_customer_name(self, obj):
        full_name = f"{obj.customer.user.first_name} {obj.customer.user.last_name}".strip()
        return full_name or obj.customer.user.username
    get_customer_name.short_description = 'Customer'
    get_customer_name.admin_order_field = 'customer__user__last_name'
    
    def get_rating_stars(self, obj):
        stars = '⭐' * obj.rating
        empty_stars = '☆' * (5 - obj.rating)
        color = self._get_rating_color(obj.rating)
        return format_html(
            '<span style="color: {}; font-size: 16px;">{}{}</span>',
            color,
            stars,
            empty_stars
        )
    get_rating_stars.short_description = 'Rating'
    
    def _get_rating_color(self, rating):
        """Return color based on rating value"""
        if rating >= 4:
            return '#28a745'  # Green for good ratings
        elif rating >= 3:
            return '#ffc107'  # Yellow for average ratings
        else:
            return '#dc3545'  # Red for poor ratings
    
    def get_comment_preview(self, obj):
        if obj.comment:
            preview = obj.comment[:50]
            if len(obj.comment) > 50:
                preview += '...'
            return preview
        return '-'
    get_comment_preview.short_description = 'Comment Preview'
    
    # Add actions for bulk operations
    actions = ['mark_as_verified', 'export_reviews']
    
    def get_queryset(self, request):
        """Optimize queries by selecting related objects"""
        qs = super().get_queryset(request)
        return qs.select_related('customer__user', 'restaurant')