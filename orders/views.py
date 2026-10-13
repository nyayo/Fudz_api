from django.db import transaction
from django.db.models import Prefetch
from django.shortcuts import render
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import filters
from rest_framework import status
from rest_framework.decorators import action
from rest_framework.mixins import (
    CreateModelMixin,
    DestroyModelMixin,
    RetrieveModelMixin,
)
from rest_framework.permissions import AllowAny, IsAdminUser, IsAuthenticated, IsAuthenticatedOrReadOnly
from rest_framework.response import Response
from rest_framework.viewsets import GenericViewSet, ModelViewSet

from delivery.models import DeliveryRequest
from delivery.tasks import auto_assign_courier
from restaurants.models import Promotion

from .models import Cart, CartItem, Order, OrderStatus
from .serializers import (
    AddCartItemSerializer,
    CartItemSerializer,
    CartSerializer,
    CreateOrderSerializer,
    OrderSerializer,
    UpdateCartItemSerializer,
    UpdateOrderSerializer,
)


class CartViewSet(
    CreateModelMixin, RetrieveModelMixin, DestroyModelMixin, GenericViewSet
):
    queryset = Cart.objects.prefetch_related(
        Prefetch(
            'items',
            queryset=CartItem.objects.select_related('menu_item').prefetch_related(
                Prefetch(
                    'menu_item__promotions',
                    queryset=Promotion.objects.filter(is_active=True)
                ),
                'menu_item__images'
            )
        )
    ).all()
    permission_classes = [IsAuthenticatedOrReadOnly]
    serializer_class = CartSerializer

    def get_queryset(self):
        if self.request.user.is_authenticated:
            return self.queryset.filter(user=self.request.user)
        return Cart.objects.none()

    def perform_create(self, serializer):
        if self.request.user.is_authenticated:
            serializer.save(user=self.request.user)
        else:
            serializer.save()

    @action(detail=True, methods=["delete"], url_path="clear")
    def clear(self, request, pk=None):
        """Delete all items from this cart in one call."""
        cart = self.get_object()
        deleted_count, _ = cart.items.all().delete()
        return Response(
            {"detail": "Cart cleared.", "deleted": deleted_count},
            status=status.HTTP_200_OK,
        )


class CartItemViewSet(ModelViewSet):
    http_method_names = ["get", "post", "patch", "delete"]
    permission_classes = [IsAuthenticated]

    def get_serializer_class(self):
        if self.request.method == "POST":
            return AddCartItemSerializer
        elif self.request.method == "PATCH":
            return UpdateCartItemSerializer
        return CartItemSerializer

    def get_serializer_context(self):
        return {"cart_id": self.kwargs["cart_pk"]}

    def get_queryset(self):
        return (
            CartItem.objects.filter(cart_id=self.kwargs["cart_pk"])
            .select_related("menu_item")
            .prefetch_related("menu_item__images", "menu_item__promotions")
            .all()
        )


class OrderViewSet(ModelViewSet):
    http_method_names = ["get", "post", "patch", "delete", "head", "options"]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ["status", "payment_status"]
    search_fields = ["id", "customer__user__first_name", "customer__user__last_name", "customer__user__email"]
    ordering_fields = ["placed_at", "total_amount", "status"]
    ordering = ["-placed_at"]

    def get_permissions(self):
        if self.action in ['list', 'retrieve']:
            return [IsAuthenticated()]
        if self.request.method in ["DELETE"]:
            return [IsAdminUser()]
        if self.request.method in ["PATCH"]:
            return [IsAuthenticated()]
        return [IsAuthenticated()]

    @transaction.atomic
    def create(self, request, *args, **kwargs):
        serializer = CreateOrderSerializer(
            data=request.data, context={"user_id": self.request.user.id}
        )
        serializer.is_valid(raise_exception=True)
        order = serializer.save()
        serializer = OrderSerializer(order)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    def perform_update(self, serializer):
        """Allow platform admins and a restaurant's own operational accounts."""
        user = self.request.user
        order = serializer.instance
        owner = getattr(user, "restaurant_profile", None)
        staff_profile = getattr(user, "restaurant_staff_profile", None)
        owns_order = bool(owner and order.restaurant_id == owner.id)
        works_here = bool(
            staff_profile
            and staff_profile.is_active
            and order.restaurant_id == staff_profile.restaurant_id
        )
        if not (user.is_staff or owns_order or works_here):
            from rest_framework.exceptions import PermissionDenied
            raise PermissionDenied("You can only update orders for your restaurant.")
        serializer.save()

    def get_serializer_class(self):
        if self.request.method == "POST":
            return CreateOrderSerializer
        elif self.request.method == "PATCH":
            return UpdateOrderSerializer
        return OrderSerializer

    def get_queryset(self):
        user = self.request.user
        base_qs = Order.objects.prefetch_related(
            "items__menu_item__images", "items__menu_item__promotions"
        ).select_related("restaurant")

        if user.is_staff:
            return base_qs.all()

        if hasattr(user, "customer_profile"):
            return base_qs.filter(customer=user.customer_profile)
        if hasattr(user, "restaurant_profile"):
            return base_qs.filter(restaurant=user.restaurant_profile)
        if hasattr(user, "restaurant_staff_profile"):
            staff_profile = user.restaurant_staff_profile
            if staff_profile.is_active:
                return base_qs.filter(restaurant=staff_profile.restaurant)
        if hasattr(user, "courier_profile"):
            return base_qs.filter(courier=user.courier_profile)

        return Order.objects.none()

    @transaction.atomic
    @action(detail=True, methods=["post"])
    def accept(self, request, pk=None):
        order = self.get_object()

        # Validate status transition
        if order.status != OrderStatus.PLACED:
            return Response(
                {"error": f"Cannot accept order in '{order.status}' status. Must be 'placed'."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        order.status = OrderStatus.ACCEPTED
        order.save(update_fields=['status'])

        delivery = DeliveryRequest.objects.create(
            order=order,
            pickup_location=order.restaurant.location,
            dropoff_location=order.dropoff_location,
        )

        transaction.on_commit(lambda: auto_assign_courier.delay(delivery.id))

        return Response(
            OrderSerializer(order).data,
            status=status.HTTP_200_OK,
        )
