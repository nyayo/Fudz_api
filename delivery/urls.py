from rest_framework.routers import DefaultRouter
from django.urls import path
from . import views

router = DefaultRouter()
router.register("deliveries", views.DeliveryRequestViewSet, basename="delivery")

urlpatterns = [path("couriers/available/", views.AvailableCouriersView.as_view(), name="available-couriers")] + router.urls
