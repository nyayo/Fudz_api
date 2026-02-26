from django.contrib import admin
from django.utils.html import format_html

from .models import MenuCategoryImage, Promotion, MenuCategory, MenuItem, MenuItemImage

class MenuCategoryImageInline(admin.TabularInline):
    model = MenuCategoryImage
    readonly_fields = ["thumbnail"]
    
    def thumbnail(self, instance):
        if instance.image != "":
            return format_html(f'<img src="{instance.image.url}" width="100" height="100" />')
        return ""

@admin.register(MenuCategory)
class MenuCategoryAdmin(admin.ModelAdmin):
    autocomplete_fields = ["restaurant"]
    list_display = ["name", "restaurant_title", "description", "is_active", "position"]
    inlines = [MenuCategoryImageInline]
    list_editable = ["is_active"]
    list_per_page = 10
    list_select_related = ["restaurant"]
    list_filter = ["restaurant", "updated_at"]
    search_fields = ["name"]

    def restaurant_title(self, category):
        return category.restaurant.restaurant_name

class MenuItemImageInline(admin.TabularInline):
    model = MenuItemImage
    readonly_fields = ["thumbnail"]
    
    def thumbnail(self, instance):
        if instance.image != "":
            return format_html(f'<img src="{instance.image.url}" width="100" height="100" />')
        return ""

@admin.register(MenuItem)
class MenuItemAdmin(admin.ModelAdmin):
    autocomplete_fields = ["restaurant"]
    list_display = ["title", "category_name", "restaurant_title", "description", "price", "is_available", "prep_time_minutes", "has_promotions"]
    list_editable = ["is_available"]
    list_per_page = 10
    list_select_related = ["restaurant", "category"]
    list_filter = ["restaurant", "category", "updated_at"]
    search_fields = ["title"]
    filter_horizontal = ["promotions"]
    inlines = [MenuItemImageInline]
    
    def has_promotions(self, obj):
        return obj.promotions.exists()
    has_promotions.boolean = True
    has_promotions.short_description = 'Has Promotions'
    
    def restaurant_title(self, menu_item):
        return menu_item.restaurant.restaurant_name

    def category_name(self, menu_item):
        return menu_item.category.name
    
    


@admin.register(Promotion)
class PromotionAdmin(admin.ModelAdmin):
    list_display = ["name", "restaurant_title", "description", "discount", "start_date", "end_date", "is_active", "is_current"]
    list_editable = ["is_active"]
    list_per_page = 10
    list_select_related = ["restaurant"]
    list_filter = ["restaurant", "is_active", "start_date", "end_date"]
    search_fields = ['name', 'description', 'restaurant__restaurant_name']
    date_hierarchy = 'start_date'

    def restaurant_title(self, promotion):
        return promotion.restaurant.restaurant_name

    def category_name(self, promotion):
        return promotion.category.name
    
    def is_current(self, obj):
        from django.utils import timezone
        now = timezone.now()
        return obj.is_active and obj.start_date <= now <= obj.end_date
    is_current.boolean = True
    is_current.short_description = 'Currently Active'
