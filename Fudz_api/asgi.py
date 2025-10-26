"""
ASGI config for Fudz_api project.

It exposes the ASGI callable as a module-level variable named ``application``.

For more information on this file, see
https://docs.djangoproject.com/en/5.2/howto/deployment/asgi/
"""

import os
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'Fudz_api.settings')
django.setup()


from channels.routing import ProtocolTypeRouter, URLRouter
from channels.auth import AuthMiddlewareStack
from delivery.routing import websocket_urlpatterns as delivery_websocket_urlpatterns
from orders.routing import websocket_urlpatterns as orders_websocket_urlpatterns


from django.core.asgi import get_asgi_application


application = ProtocolTypeRouter({
    "http": get_asgi_application(),
    "websocket": AuthMiddlewareStack(
        URLRouter(
            delivery_websocket_urlpatterns + orders_websocket_urlpatterns
        )
    )
})
