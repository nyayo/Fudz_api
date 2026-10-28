import os
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'Fudz_api.settings')
django.setup()


from channels.routing import ProtocolTypeRouter, URLRouter
from channels.auth import AuthMiddlewareStack
from channels.security.websocket import OriginValidator
from django.conf import settings
from delivery.routing import websocket_urlpatterns as delivery_websocket_urlpatterns
from orders.routing import websocket_urlpatterns as orders_websocket_urlpatterns


from django.core.asgi import get_asgi_application


application = ProtocolTypeRouter({
    "http": get_asgi_application(),
    "websocket": OriginValidator(AuthMiddlewareStack(
        URLRouter(
            delivery_websocket_urlpatterns + orders_websocket_urlpatterns
        )
    ), settings.BROWSER_SESSION_ORIGINS)
})
