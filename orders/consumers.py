import json
from channels.generic.websocket import AsyncWebsocketConsumer

class AdminNotificationConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        user = self.scope.get('user')
        if user.is_active and user.is_staff:
            await self.channel_layer.group_add("admin_notifications", self.channel_name)
            await self.accept()
        else:
            await self.close()

    async def disconnect(self, close_code):
        user = self.scope.get('user')
        if user.is_active and user.is_staff:
            await self.channel_layer.group_discard("admin_notifications", self.channel_name)

    async def admin_notification(self, event):
        await self.send(text_data=json.dumps({
            "type": event["event_type"],
            "notification_id": event["notification_id"],
            "order_id": event["order_id"],
            "customer": event["customer"],
            "restaurant": event["restaurant"],
            "status": event["status"],
            "message": event["message"],
            "redirect_url": event["redirect_url"],
        }))
