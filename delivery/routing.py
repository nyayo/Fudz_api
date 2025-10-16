from django.urls import path
from . import consumers

websocket_urlpatterns = [
    path('ws/courier/location/<int:courier_id>/', consumers.CourierLocationConsumer.as_asgi()),
]
