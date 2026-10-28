import json

from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async

from django.utils import timezone
from django.core.cache import cache

from users.models import CustomerProfile, User
from django.contrib.gis.geos import Point
from .models import DeliveryRequest
import math


class CustomerLocationConsumer(AsyncWebsocketConsumer):
    """Consumer to receive and broadcast customer location updates"""    
    async def connect(self):
        self.customer_id = self.scope['url_route']['kwargs']['customer_id']
        user = self.scope.get("user")
        if not user or not user.is_authenticated or not user.is_active or user.pk != self.customer_id:
            await self.close(code=4403)
            return
        await self.accept()
        
        await self.channel_layer.group_add(
            f"customer_{self.customer_id}", 
            self.channel_name
        )
        
        await self.send(text_data=json.dumps({
            'type': 'connection_established',
            'message': f'Connected as customer {self.customer_id}'
        }))

    async def disconnect(self, close_code):
        if hasattr(self, "customer_id"):
            await self.channel_layer.group_discard(f"customer_{self.customer_id}", self.channel_name)

    async def receive(self, text_data):
        """Receive customer location updates"""
        try:
            data = json.loads(text_data)
            lat = data.get('lat')
            lng = data.get('lng')

            if (isinstance(lat, (int, float)) and not isinstance(lat, bool)
                    and isinstance(lng, (int, float)) and not isinstance(lng, bool)
                    and math.isfinite(lat) and math.isfinite(lng)
                    and -90 <= lat <= 90 and -180 <= lng <= 180):
                point = Point(lng, lat)
                delivery = await self.update_customer_location(point)

                location_data = {
                    'type': 'customer_location_update',
                    'customer_id': self.customer_id,
                    'lat': lat,
                    'lng': lng,
                    'timestamp': timezone.now().isoformat()
                }

                if delivery and delivery.courier:
                    await self.channel_layer.group_send(
                        f"courier_{delivery.courier.id}",
                        location_data
                    )
                    
                    await self.channel_layer.group_send(
                        f"delivery_{delivery.id}",
                        location_data
                    )

                cache.set(
                    f"customer:{self.customer_id}",
                    {
                        "lat": lat, 
                        "lng": lng, 
                        "timestamp": timezone.now().isoformat()
                    },
                    timeout=60 * 10
                )

                await self.send(text_data=json.dumps({
                    'type': 'location_received',
                    'lat': lat,
                    'lng': lng,
                    'delivery_id': delivery.id if delivery else None,
                    'courier_notified': bool(delivery and delivery.courier_id)
                }))

        except Exception as e:
            await self.send(text_data=json.dumps({
                'type': 'error',
                'message': 'Invalid location update.'
            }))

    async def customer_location_update(self, event):
        await self.location_update(event)

    async def location_update(self, event):
        """Handler for location updates from group_send"""
        await self.send(text_data=json.dumps({
            'type': 'location_update',
            'customer_id': event.get('customer_id'),
            'lat': event['lat'],
            'lng': event['lng'],
            'timestamp': event['timestamp']
        }))

    @database_sync_to_async
    def update_customer_location(self, point):
        """Update customer location in database"""
        try:
            customer = User.objects.get(id=self.customer_id)
            
            customer_profile = CustomerProfile.objects.get(user=customer)
            customer_profile.current_location = point
            customer_profile.save(update_fields=["current_location"])
            return DeliveryRequest.objects.select_related("courier").filter(
                order__customer=customer_profile,
                status__in=["assigned", "accepted", "picked_up"],
            ).first()

        except (User.DoesNotExist, CustomerProfile.DoesNotExist):
            pass


class DeliveryTrackingConsumer(AsyncWebsocketConsumer):
    """Passive consumer for customers to receive delivery tracking updates."""

    async def connect(self):
        self.delivery_id = self.scope["url_route"]["kwargs"]["delivery_id"]
        self.group_name = f"delivery_{self.delivery_id}"
        user = self.scope.get("user")
        if not user or not user.is_authenticated or not user.is_active or not await self.can_track(user):
            await self.close(code=4403)
            return

        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()

        await self.send(
            text_data=json.dumps(
                {
                    "type": "connection_established",
                    "message": f"Connected to delivery {self.delivery_id} tracking",
                }
            )
        )

    @database_sync_to_async
    def can_track(self, user):
        delivery = DeliveryRequest.objects.select_related("order__customer", "order__restaurant", "courier").filter(pk=self.delivery_id).first()
        if not delivery:
            return False
        if user.is_staff:
            return True
        order = delivery.order
        if order.customer.user_id == user.pk or order.restaurant.user_id == user.pk:
            return True
        if delivery.courier and delivery.courier.user_id == user.pk:
            return True
        staff = getattr(user, "restaurant_staff_profile", None)
        return bool(staff and staff.is_active and staff.restaurant_id == order.restaurant_id)

    async def disconnect(self, close_code):
        if hasattr(self, "group_name"):
            await self.channel_layer.group_discard(self.group_name, self.channel_name)

    async def receive(self, text_data):
        await self.send(
            text_data=json.dumps(
                {
                    "type": "info",
                    "message": "This WebSocket is for receiving tracking updates only.",
                }
            )
        )

    async def customer_location_update(self, event):
        await self.location_update(event)

    async def location_update(self, event):
        await self.send(
            text_data=json.dumps(
                {
                    "type": "location_update",
                    "lat": event["lat"],
                    "lng": event["lng"],
                    "timestamp": event["timestamp"],
                }
            )
        )
