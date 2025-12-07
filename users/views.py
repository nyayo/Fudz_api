from rest_framework import status, generics, viewsets
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.generics import GenericAPIView
from rest_framework.views import APIView

from push_notifications.models import GCMDevice, APNSDevice, WebPushDevice

from django.utils import timezone
from django.utils.http import urlsafe_base64_decode
from django.utils.encoding import smart_str, DjangoUnicodeDecodeError
from django.contrib.auth.tokens import PasswordResetTokenGenerator

from users.permissions import IsRestaurantOwner

from .helpers import get_tokens_for_user, register_social_user
from .models import EmailVerification, RestaurantStaffProfile, User
from .serializers import (
    GoogleSignInSerializer,
    RegistrationSerializer,
    SetNewPasswordSerializer, 
    UserProfileSerializer,
    RequestOTPSerializer, 
    VerifyOTPSerializer, 
    LogoutUserSerializer,
    PasswordResetRequestSerializer,
    RestaurantStaffSerializer
    )
from .services import OTPService
from .tasks import send_push_notification_to_user


class RequestOTPView(GenericAPIView):
    serializer_class = RequestOTPSerializer
    permission_classes = [AllowAny]

    def post(self, request):
        from .services import send_normal_email
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        email = serializer.validated_data.get('email')
        
        try:
            otp_obj, created = EmailVerification.objects.get_or_create(
                email=email,
                is_verified=False,
                defaults={'expires_at': timezone.now() + timezone.timedelta(minutes=10)}
            )
            
            if not created:
                otp_obj.is_verified = False
                otp_obj.expires_at = timezone.now() + timezone.timedelta(minutes=10)
            
            otp_obj.generate_otp()

            email_body=f"Your verification code is: {otp_obj.otp}. Valid for 10 minutes."
            data={
                'email_body':email_body, 
                'email_subject':"Registration OTP", 
                'to_email':email
                }

            OTPService.send_otp(email, otp_obj.otp)
            send_normal_email(data)

            return Response({
                'message': 'OTP sent successfully to your email'
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            return Response({
                'message': 'Failed to generate OTP',
                'error': str(e)
            }, status=status.HTTP_400_BAD_REQUEST)


class VerifyOTPView(generics.CreateAPIView):
    serializer_class = VerifyOTPSerializer
    permission_classes = [AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        result = serializer.save()

        if result['user_exists']:
            user = User.objects.get(email=result['email'])
            tokens = get_tokens_for_user(user)
            return Response({
                'message': 'Login successful',
                'verified': True,
                'user_exists': True,
                'requires_registration': False,
                'user': UserProfileSerializer(user).data,
                'tokens': tokens
            }, status=status.HTTP_200_OK)

        return Response({
            'message': 'Email verified. Please complete registration.',
            'verified': True,
            'user_exists': False,
            'requires_registration': True,
            'email': result['email']
        }, status=status.HTTP_200_OK)


class RegisterView(generics.CreateAPIView):
    serializer_class = RegistrationSerializer
    permission_classes = [AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        tokens = get_tokens_for_user(user)
        return Response(
            {
                "message": "Registration successful.",
                "user": UserProfileSerializer(user).data,
                "tokens": tokens,
            },
            status=status.HTTP_201_CREATED,
        )


class GoogleOauthSignInview(generics.GenericAPIView):
    serializer_class = GoogleSignInSerializer
    queryset = User.objects.none()
    permission_classes = [AllowAny]
    
    def post(self, request):
        print(request.data)
        serializer = self.serializer_class(data=request.data)
        serializer.is_valid(raise_exception=True)

        google_data = serializer.validated_data['_google_data']

        response = register_social_user(
            provider=google_data['provider'],
            email=google_data['email'],
            first_name=google_data['first_name'],
            last_name=google_data['last_name'],
            user_type=google_data['user_type'],
            profile_data=google_data['profile_data']
        )
        
        return Response(response.data, status=response.status_code)


class LogoutApiView(GenericAPIView):
    serializer_class=LogoutUserSerializer
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer=self.serializer_class(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(status=status.HTTP_204_NO_CONTENT)

class PasswordResetRequestView(GenericAPIView):
    serializer_class=PasswordResetRequestSerializer
    queryset = User.objects.none()
    permission_classes = [AllowAny]

    def post(self, request):
        serializer=self.serializer_class(data=request.data, context={'request':request})
        serializer.is_valid(raise_exception=True)
        return Response({'message':'we have sent you a link to reset your password'}, status=status.HTTP_200_OK)
        # return Response({'message':'user with that email does not exist'}, status=status.HTTP_400_BAD_REQUEST)
    

class PasswordResetConfirm(APIView):
    queryset = User.objects.none()

    def get(self, request, uidb64, token):
        try:
            user_id=smart_str(urlsafe_base64_decode(uidb64))
            user=User.objects.get(id=user_id)

            if not PasswordResetTokenGenerator().check_token(user, token):
                return Response({'message':'token is invalid or has expired'}, status=status.HTTP_401_UNAUTHORIZED)
            return Response({'success':True, 'message':'credentials is valid', 'uidb64':uidb64, 'token':token}, status=status.HTTP_200_OK)

        except DjangoUnicodeDecodeError as identifier:
            return Response({'message':'token is invalid or has expired'}, status=status.HTTP_401_UNAUTHORIZED)
        

class SetNewPasswordView(APIView):
    serializer_class=SetNewPasswordSerializer
    queryset = User.objects.none()
    permission_classes = [AllowAny]

    def patch(self, request):
        serializer=self.serializer_class(data=request.data)
        serializer.is_valid(raise_exception=True)
        return Response({'success':True, 'message':"password reset is succesful"}, status=status.HTTP_200_OK)


class UserProfileView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        serializer = UserProfileSerializer(request.user)
        return Response(serializer.data, status=status.HTTP_200_OK)
    def put(self, request):
        user = request.user
        serializer = UserProfileSerializer(user, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()

            if user.user_type == "restaurant" and "profile" in request.data:
                profile_data = request.data.get("profile", {})
                restaurant_profile = user.restaurant_profile
                for key, value in profile_data.items():
                    setattr(restaurant_profile, key, value)
                restaurant_profile.save()

            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
class RestaurantStaffViewSet(viewsets.ModelViewSet):
    queryset = RestaurantStaffProfile.objects.all()
    serializer_class = RestaurantStaffSerializer
    permission_classes = [IsAuthenticated, IsRestaurantOwner]

    def get_queryset(self):
        print(f"User: {self.request.user}")
        restaurant = self.request.user.restaurant_profile
        return RestaurantStaffProfile.objects.filter(restaurant=restaurant)

    def perform_create(self, serializer):
        restaurant = self.request.user.restaurant_profile
        serializer.save(restaurant=restaurant)    
    
    
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def register_device(request):
    """
    Register a device for push notifications
    
    POST data:
    {
        "registration_id": "device-token",
        "type": "android|ios|web",
        "name": "optional-device-name"
    }
    """
    device_type = request.data.get('type')
    registration_id = request.data.get('registration_id')
    name = request.data.get('name', '')
    
    if not registration_id or not device_type:
        return Response({'error': 'registration_id and type are required'}, status=400)
    
    try:
        if device_type == 'android':
            device, created = GCMDevice.objects.get_or_create(
                registration_id=registration_id,
                defaults={'user': request.user, 'name': name}
            )
        elif device_type == 'ios':
            device, created = APNSDevice.objects.get_or_create(
                registration_id=registration_id,
                defaults={'user': request.user, 'name': name}
            )
        elif device_type == 'web':
            device, created = WebPushDevice.objects.get_or_create(
                registration_id=registration_id,
                defaults={'user': request.user, 'name': name}
            )
        else:
            return Response({'error': 'Invalid device type'}, status=400)

        if not created:
            device.user = request.user
            device.active = True
            device.save()
        
        return Response({
            'success': True,
            'created': created,
            'device_id': device.id
        })
        
    except Exception as e:
        return Response({'error': str(e)}, status=500)   
    
    
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def send_test_notification(request):
    """
    Send a test notification to the current user
    """
    title = request.data.get('title', 'Test Notification')
    message = request.data.get('message', 'This is a test message')
    data = request.data.get('data', {})
    
    send_push_notification_to_user.delay(
        request.user.id,
        title,
        message,
        data
    )
    
    return Response({'success': True, 'message': 'Notification queued'})


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def unregister_device(request):
    """
    Unregister a device
    
    POST data:
    {
        "registration_id": "device-token"
    }
    """
    registration_id = request.data.get('registration_id')
    
    if not registration_id:
        return Response({'error': 'registration_id required'}, status=400)
  
    for model in [GCMDevice, APNSDevice, WebPushDevice]:
        try:
            device = model.objects.get(
                registration_id=registration_id,
                user=request.user
            )
            device.active = False
            device.save()
            return Response({'success': True, 'message': 'Device unregistered'})
        except model.DoesNotExist:
            continue
    
    return Response({'error': 'Device not found'}, status=404)
