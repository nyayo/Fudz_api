from django.contrib import admin
from .models import Wishlist, WishlistItem


class WishlistItemInline(admin.TabularInline):
    model = WishlistItem
    extra = 1
    autocomplete_fields = ['menu_item']
    readonly_fields = ('added_at',)
    fields = ('menu_item', 'added_at')


@admin.register(Wishlist)
class WishlistAdmin(admin.ModelAdmin):
    list_display = ('customer', 'get_customer_username', 'item_count', 'created_at')
    list_filter = ('created_at',)
    search_fields = (
        'customer__user__username',
        'customer__user__email',
        'customer__user__first_name',
        'customer__user__last_name'
    )
    readonly_fields = ('created_at',)
    autocomplete_fields = ['customer']
    inlines = [WishlistItemInline]
    
    def get_customer_username(self, obj):
        return obj.customer.user.username
    get_customer_username.short_description = 'Username'
    get_customer_username.admin_order_field = 'customer__user__username'
    
    def item_count(self, obj):
        return obj.items.count()
    item_count.short_description = 'Items'


@admin.register(WishlistItem)
class WishlistItemAdmin(admin.ModelAdmin):
    list_display = (
        'menu_item',
        'get_customer_username',
        'get_menu_item_restaurant',
        'added_at'
    )
    list_filter = ('added_at', 'menu_item__restaurant')
    search_fields = (
        'wishlist__customer__user__username',
        'menu_item__name',
        'menu_item__restaurant__name'
    )
    readonly_fields = ('added_at',)
    autocomplete_fields = ['wishlist', 'menu_item']
    date_hierarchy = 'added_at'
    
    def get_customer_username(self, obj):
        return obj.wishlist.customer.user.username
    get_customer_username.short_description = 'Customer'
    get_customer_username.admin_order_field = 'wishlist__customer__user__username'
    
    def get_menu_item_restaurant(self, obj):
        return obj.menu_item.restaurant.restaurant_name if hasattr(obj.menu_item, 'restaurant') else '-'
    get_menu_item_restaurant.short_description = 'Restaurant'