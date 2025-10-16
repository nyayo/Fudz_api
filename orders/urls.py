from django.urls import path
from rest_framework_nested import routers
from rest_framework.routers import DefaultRouter
from . import views


router = routers.DefaultRouter()
router.register('carts', views.CartViewSet, basename='cart')
router.register('orders', views.OrderViewSet, basename='order')

carts_router = routers.NestedDefaultRouter(router, 'carts', lookup='cart')
carts_router.register('items', views.CartItemViewSet, basename='cart-items')


urlpatterns = router.urls + carts_router.urls
