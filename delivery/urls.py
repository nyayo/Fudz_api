from django.urls import path
from rest_framework_nested import routers
from rest_framework.routers import DefaultRouter
from . import views


router = routers.DefaultRouter()
router.register('deliveries', views.DeliveryRequestViewSet, basename='delivery')


urlpatterns = router.urls + [
    path('earnings/', views.CourierEarningsListView.as_view(), name='courier-earnings-list'),
    path('earnings/summary/', views.CourierEarningsSummaryView.as_view(), name='courier-earnings-summary'),
]