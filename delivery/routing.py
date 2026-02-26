from django.urls import path
from . import consumers

websocket_urlpatterns = [
    path('ws/customer/<int:customer_id>/', consumers.CustomerLocationConsumer.as_asgi()),
    path('ws/courier/location/<int:courier_id>/', consumers.CourierLocationConsumer.as_asgi()),
    path('ws/delivery/track/<int:delivery_id>/', consumers.DeliveryTrackingConsumer.as_asgi()),
]
