from django.urls import path
from rest_framework_nested import routers
from rest_framework.routers import DefaultRouter
from . import views


router = routers.DefaultRouter()
router.register('carts', views.CartViewSet, basename='cart')
router.register('orders', views.OrderViewSet, basename='order')

carts_router = routers.NestedDefaultRouter(router, 'carts', lookup='cart')
carts_router.register('items', views.CartItemViewSet, basename='cart-items')


urlpatterns = [
    path("notifications/", views.notification_inbox, name="notification-inbox"),
    path("notifications/mark-all-read/", views.mark_all_notifications_read, name="notifications-mark-all-read"),
    path("notifications/<int:pk>/read/", views.mark_notification_read, name="notification-mark-read"),
] + router.urls + carts_router.urls
