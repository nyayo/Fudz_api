import json
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from django.contrib.gis.geos import Point
from django.utils import timezone
from users.models import CourierProfile
from django.core.cache import cache

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
                await self.update_courier_location(point)

                cache.set(
                    f"courier:{self.courier_id}",
                    {
                        "lat": lat, 
                        "lng": lng, 
                        "timestamp": timezone.now().isoformat()
                    },
                    timeout=60 * 10
                )
                
                await self.channel_layer.group_send(
                    f"courier_{self.courier_id}",
                    {
                        'type': 'location_update',
                        'lat': lat,
                        'lng': lng,
                        'timestamp': timezone.now().isoformat()
                    }
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
        except CourierProfile.DoesNotExist:
            pass 