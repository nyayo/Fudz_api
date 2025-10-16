from django.shortcuts import render

from rest_framework import status
from rest_framework.mixins import CreateModelMixin, RetrieveModelMixin, DestroyModelMixin
from rest_framework.viewsets import GenericViewSet, ModelViewSet
from rest_framework.permissions import AllowAny, IsAuthenticated, IsAdminUser
from rest_framework.response import Response
from rest_framework.decorators import action

from delivery.models import DeliveryRequest
from delivery.tasks import auto_assign_courier
from .models import Cart, CartItem, Order
from .serializers import CartSerializer, CartItemSerializer, AddCartItemSerializer, OrderSerializer, UpdateCartItemSerializer, CreateOrderSerializer, UpdateOrderSerializer


class CartViewSet(CreateModelMixin, RetrieveModelMixin, DestroyModelMixin, GenericViewSet):
    queryset = Cart.objects.prefetch_related('items__menu_item').all()
    permission_classes = [AllowAny]
    serializer_class = CartSerializer


class CartItemViewSet(ModelViewSet):
    http_method_names = ['get', 'post', 'patch', 'delete']
    permission_classes = [AllowAny]
    
    def get_serializer_class(self):
        if self.request.method == 'POST':
            return AddCartItemSerializer
        elif self.request.method == 'PATCH':
            return UpdateCartItemSerializer
        return CartItemSerializer
    
    def get_serializer_context(self):
        return {'cart_id': self.kwargs['cart_pk']}
    
    
    def get_queryset(self):
        return CartItem.objects.filter(cart_id=self.kwargs['cart_pk']).select_related('menu_item').all()
    
    
class OrderViewSet(ModelViewSet):
    http_method_names = ['get', 'post', 'patch', 'delete', 'head', 'options']
    
    def get_permissions(self):
        if self.request.method in ['PATCH', 'DELETE']:
            return [IsAdminUser()]
        return [IsAuthenticated()]
    
    def create(self, request, *args, **kwargs):
        serializer = CreateOrderSerializer(data=request.data, context={'user_id': self.request.user.id})
        serializer.is_valid(raise_exception=True)
        order = serializer.save()
        serializer = OrderSerializer(order)
        return Response(serializer.data, status=status.HTTP_201_CREATED)
    
    def get_serializer_class(self):
        if self.request.method == 'POST':
            return CreateOrderSerializer
        elif self.request.method == 'PATCH':
            return UpdateOrderSerializer
        return OrderSerializer
    
    def get_queryset(self):
        user = self.request.user
        if user.is_staff:
            return Order.objects.all()

        if hasattr(user, 'customer_profile'):
            return Order.objects.filter(customer=user.customer_profile)
        if hasattr(user, 'restaurant_profile'):
            return Order.objects.filter(restaurant=user.restaurant_profile)
        if hasattr(user, 'courier_profile'):
            return Order.objects.filter(courier=user.courier_profile)

        return Order.objects.none()
    
    
    @action(detail=True, methods=["post"])
    def accept(self, request, pk=None):
        order = self.get_object()
        order.status = "accepted"
        order.save()

        delivery = DeliveryRequest.objects.create(
            order=order,
            pickup_location=order.restaurant.location,
            dropoff_location=order.dropoff_location,
        )
        
        print("Order accepted by restaurant, delivery request created.")

        auto_assign_courier.delay(delivery.id)

        return Response(
            {"message": "Order accepted and delivery request created"}
        )
