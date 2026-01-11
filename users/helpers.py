import requests
from datetime import timedelta

from django.contrib.auth import authenticate
from django.conf import settings
from django.utils import timezone

from rest_framework.exceptions import AuthenticationFailed
from rest_framework.response import Response
from rest_framework import status
from rest_framework_simplejwt.tokens import RefreshToken

from google.auth.transport import requests
from google.oauth2 import id_token

from .models import CustomerProfile, User, RestaurantProfile, CourierProfile
from .serializers import UserProfileSerializer



class Google():
    @staticmethod
    def validate(access_token):
        try:
            id_info=id_token.verify_oauth2_token(access_token, requests.Request())
            if 'accounts.google.com' in id_info['iss']:
                return id_info
        except:
            return "the token is either invalid or has expired"

def create_user_profile(user, user_type, profile_data):
    """Create appropriate profile based on user type"""
    if user_type == 'customer':
        CustomerProfile.objects.create(user=user, **profile_data)
    elif user_type == 'restaurant':
        RestaurantProfile.objects.create(user=user, **profile_data)
    elif user_type == 'courier':
        CourierProfile.objects.create(user=user, **profile_data)

def register_social_user(provider, email, first_name, last_name, user_type, profile_data):
    old_user=User.objects.filter(email=email)
    if old_user.exists():
        if provider == old_user[0].auth_provider:
            register_user=authenticate(email=email, password=settings.SOCIAL_AUTH_PASSWORD)

            tokens = get_tokens_for_user(register_user)
            return Response(
                {
                    "message": "Registration successful.",
                    "user": UserProfileSerializer(register_user).data,
                    "tokens": tokens,
                },
                status=status.HTTP_201_CREATED,
            )
        else:
            raise AuthenticationFailed(
                detail=f"please continue your login with {old_user[0].auth_provider}"
            )
    else:
        new_user = {
            'email': email,
            'first_name': first_name,
            'last_name': last_name,
            'password': settings.SOCIAL_AUTH_PASSWORD,
            'user_type': user_type
        }
        
        if 'phone' in profile_data:
            new_user['phone'] = profile_data.pop('phone')
                 
        user = User.objects.create_user(**new_user)
        user.auth_provider = provider
        user.is_verified = True
        user.save()
        
        create_user_profile(user, user_type, profile_data)
        
        login_user = authenticate(email=email, password=settings.SOCIAL_AUTH_PASSWORD)
        tokens = get_tokens_for_user(login_user)
        
        return Response(
            {
                "message": "Login successful.",
                "user": UserProfileSerializer(login_user).data,
                "tokens": tokens,
            },
            status=status.HTTP_201_CREATED,
        )
        
        
def get_tokens_for_user(user):
    refresh = RefreshToken.for_user(user)
    return {"refresh": str(refresh), "access": str(refresh.access_token)}

def send_order_notification(user, title, order):
    from .tasks import send_push_notification_to_user
    
    send_push_notification_to_user.delay(
        user.id,
        f"Order {title}",
        f"Your order #{order.id} has been {title.lower()}!",
        {'order_id': order.id, 'type': 'order_update'}
    )
    
def notify_new_promotion(promotion, user_ids):
    from .tasks import send_fcm_to_multiple_users
    
    send_fcm_to_multiple_users.delay(
        user_ids,
        "New Promotion!",
        f"{promotion.name} - {promotion.discount}% off",
        {
            'promotion_id': str(promotion.id),
            'type': 'promotion'
        }
    )
    
def convert_data_to_strings(data):
    if not data:
        return {}
    
    converted = {}
    for key, value in data.items():
        if value is None:
            converted[key] = ""
        elif isinstance(value, bool):
            converted[key] = "true" if value else "false"
        elif isinstance(value, (int, float)):
            converted[key] = str(value)
        elif isinstance(value, (dict, list)):
            import json
            converted[key] = json.dumps(value)
        else:
            converted[key] = str(value)
    
    return converted