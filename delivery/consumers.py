import json

from django.contrib.gis.geos import Point
from django.utils import timezone
from django.core.cache import cache

from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async

from users.models import CourierProfile, CustomerProfile, User
from .models import DeliveryRequest, DeliveryTracking

class CourierLocationConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.courier_id = self.scope['url_route']['kwargs']['courier_id']

        # user = self.scope.get('user')
        # if user is None or not user.is_authenticated:
        #     await self.close()
        #     return
        await self.accept()

        await self.channel_layer.group_add(
            f"courier_{self.courier_id}", 
            self.channel_name
        )

        await self.send(text_data=json.dumps({
            'type': 'connection_established',
            'message': f'Connected to courier {self.courier_id}'
        }))

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(
            f"courier_{self.courier_id}", 
            self.channel_name
        )

    async def receive(self, text_data):
        try:
            data = json.loads(text_data)
            lat = data.get('lat')
            lng = data.get('lng')
            
            if lat and lng:
                point = Point(lng, lat)
                delivery = await self.update_courier_location(point)
                
                if delivery:
                    await self.channel_layer.group_send(
                        f"delivery_{delivery.id}",
                        {
                            'type': 'location_update',
                            'lat': lat,
                            'lng': lng,
                            'timestamp': timezone.now().isoformat()
                        }
                    )

                cache.set(
                    f"courier:{self.courier_id}",
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
                    'lng': lng
                }))
        except Exception as e:
            await self.send(text_data=json.dumps({
                'type': 'error',
                'message': str(e)
            }))

    async def location_update(self, event):
        """Handler for location updates from group_send"""
        await self.send(text_data=json.dumps({
            'type': 'location_update',
            'lat': event['lat'],
            'lng': event['lng'],
            'timestamp': event['timestamp']
        }))
        
    @database_sync_to_async
    def update_courier_location(self, point):
        try:
            courier = CourierProfile.objects.get(id=self.courier_id)
            courier.current_location = point
            courier.last_updated = timezone.now()
            courier.save()

            delivery = DeliveryRequest.objects.filter(
                courier=courier, status__in=["assigned", "accepted", "picked_up"]
            ).first()

            if delivery:
                DeliveryTracking.objects.create(
                    delivery=delivery,
                    courier=courier,
                    current_location=point
                )
                return delivery
        except CourierProfile.DoesNotExist:
            pass

class CustomerLocationConsumer(AsyncWebsocketConsumer):
    """Consumer to receive and broadcast customer location updates"""    
    async def connect(self):
        self.customer_id = self.scope['url_route']['kwargs']['customer_id']
        # user = self.scope.get('user')
        # if user is None or not user.is_authenticated:
        #     await self.close()
        #     return
        
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
        await self.channel_layer.group_discard(
            f"customer_{self.customer_id}", 
            self.channel_name
        )

    async def receive(self, text_data):
        """Receive customer location updates"""
        try:
            data = json.loads(text_data)
            lat = data.get('lat')
            lng = data.get('lng')

            if lat and lng:
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
                    'courier_notified': delivery and delivery.courier is not None
                }))

        except Exception as e:
            await self.send(text_data=json.dumps({
                'type': 'error',
                'message': str(e)
            }))

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
            customer_profile.last_updated = timezone.now()
            customer_profile.save()

        except (User.DoesNotExist, CustomerProfile.DoesNotExist):
            pass


class DeliveryTrackingConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.delivery_id = self.scope['url_route']['kwargs']['delivery_id']
        self.group_name = f"delivery_{self.delivery_id}"

        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()

        await self.send(text_data=json.dumps({
            'type': 'connection_established',
            'message': f'Connected to delivery {self.delivery_id} tracking'
        }))

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(self.group_name, self.channel_name)

    async def receive(self, text_data):
        await self.send(text_data=json.dumps({
            'type': 'info',
            'message': 'This WebSocket is for receiving tracking updates only.'
        }))

    async def location_update(self, event):
        """Receives courier updates from CourierLocationConsumer"""
        await self.send(text_data=json.dumps({
            'type': 'location_update',
            'lat': event['lat'],
            'lng': event['lng'],
            'timestamp': event['timestamp']
        }))
        
        
        
        