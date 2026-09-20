from django.urls import path
from rest_framework.routers import DefaultRouter
from . import views


router = DefaultRouter()
router.register('deliveries', views.DeliveryRequestViewSet, basename='delivery')

urlpatterns = [
    path('earnings/', views.CourierEarningsListView.as_view(), name='courier-earnings'),
    path('earnings/summary/', views.CourierEarningsSummaryView.as_view(), name='courier-earnings-summary'),
] + router.urls
