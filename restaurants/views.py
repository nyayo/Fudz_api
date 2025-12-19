from django.db.models import Avg, Count, Q
from django.utils import timezone
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import filters, generics, status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.viewsets import ModelViewSet

from users.models import RestaurantProfile
from users.permissions import IsManagerOrReadOnly

from .models import MenuCategory, MenuCategoryImage, MenuItem, MenuItemImage, Promotion
from .permissions import IsAdminOrRestaurantOwner, IsOwnerOrReadOnly
from .serializers import (
    MenuCategoryImageSerializer,
    MenuCategoryListSerializer,
    MenuCategorySerializer,
    MenuItemImageSerializer,
    MenuItemSerializer,
    PromotionSerializer,
    RestaurantProfileSerializer,
)


class PromotionViewSet(viewsets.ModelViewSet):
    queryset = Promotion.objects.select_related("restaurant").all()
    serializer_class = PromotionSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        """Filter promotions by restaurant if user is restaurant owner"""
        queryset = super().get_queryset()
        if hasattr(self.request.user, "restaurant_profile"):
            print(f"Filtering promotions for {self.request.user.restaurant_profile.id}")
            return queryset.filter(restaurant=self.request.user.restaurant_profile)
        return queryset

    @action(detail=False, methods=["get"])
    def active(self, request):
        """Get only currently active promotions"""
        now = timezone.now()
        queryset = self.get_queryset().filter(
            is_active=True, start_date__lte=now, end_date__gte=now
        )
        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=["post"])
    def toggle_active(self, request, pk=None):
        """Toggle promotion active status"""
        promotion = self.get_object()
        promotion.is_active = not promotion.is_active
        promotion.save()
        serializer = self.get_serializer(promotion)
        return Response(serializer.data)

    @action(detail=True, methods=["get"])
    def menu_items(self, request, pk=None):
        """Get all menu items with this promotion"""
        promotion = self.get_object()
        menu_items = promotion.menuitem_set.all()
        serializer = MenuItemSerializer(menu_items, many=True)
        return Response(serializer.data)


class MenuItemListCreateView(generics.ListCreateAPIView):
    queryset = MenuItem.objects.select_related("restaurant", "category").all()
    serializer_class = MenuItemSerializer
    permission_classes = [IsAdminOrRestaurantOwner, IsManagerOrReadOnly]
    filter_backends = [
        DjangoFilterBackend,
        filters.SearchFilter,
        filters.OrderingFilter,
    ]
    filterset_fields = ["restaurant", "category", "is_available", "is_featured"]
    search_fields = ["title", "description"]
    ordering_fields = ["price", "title", "created_at"]
    ordering = ["category__position", "title"]

    def get_queryset(self):
        queryset = super().get_queryset()

        if (
            hasattr(self.request.user, "restaurant_profile")
            and not self.request.user.is_staff
        ):
            queryset = queryset.filter(restaurant=self.request.user.restaurant_profile)

        restaurant_id = self.request.query_params.get("restaurant_id")
        if restaurant_id:
            queryset = queryset.filter(restaurant_id=restaurant_id)

        return queryset

    def get_serializer_context(self):
        """Pass request context to serializer"""
        context = super().get_serializer_context()
        context["request"] = self.request
        return context

    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()

        if hasattr(instance, "orderitems") and instance.orderitems.count() > 0:
            return Response(
                {"error": "Cannot delete menu item with existing orders."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        return super().destroy(request, *args, **kwargs)

    @action(detail=True, methods=["post"])
    def add_promotion(self, request, pk=None):
        """Add a promotion to menu item"""
        menu_item = self.get_object()
        promotion_id = request.data.get("promotion_id")

        try:
            promotion = Promotion.objects.get(
                id=promotion_id, restaurant=menu_item.restaurant
            )
            menu_item.promotions.add(promotion)
            serializer = self.get_serializer(menu_item)
            return Response(serializer.data)
        except Promotion.DoesNotExist:
            return Response(
                {"error": "Promotion not found or does not belong to this restaurant"},
                status=status.HTTP_404_NOT_FOUND,
            )

    @action(detail=True, methods=["post"])
    def remove_promotion(self, request, pk=None):
        """Remove a promotion from menu item"""
        menu_item = self.get_object()
        promotion_id = request.data.get("promotion_id")

        try:
            promotion = Promotion.objects.get(id=promotion_id)
            menu_item.promotions.remove(promotion)
            serializer = self.get_serializer(menu_item)
            return Response(serializer.data)
        except Promotion.DoesNotExist:
            return Response(
                {"error": "Promotion not found"}, status=status.HTTP_404_NOT_FOUND
            )

    @action(detail=False, methods=["get"])
    def on_promotion(self, request):
        """Get all menu items with active promotions"""
        now = timezone.now()
        queryset = (
            self.get_queryset()
            .filter(
                promotions__is_active=True,
                promotions__start_date__lte=now,
                promotions__end_date__gte=now,
            )
            .distinct()
        )
        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)


class MenuItemRetrieveUpdateDestroyView(generics.RetrieveUpdateDestroyAPIView):
    queryset = MenuItem.objects.select_related("restaurant", "category").all()
    serializer_class = MenuItemSerializer
    permission_classes = [IsOwnerOrReadOnly, IsManagerOrReadOnly]

    def get_queryset(self):
        queryset = super().get_queryset()

        if (
            hasattr(self.request.user, "restaurant_profile")
            and not self.request.user.is_staff
        ):
            queryset = queryset.filter(restaurant=self.request.user.restaurant_profile)

        return queryset

    def get_serializer_context(self):
        """Pass request context to serializer"""
        context = super().get_serializer_context()
        context["request"] = self.request
        return context

    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()

        if hasattr(instance, "orderitems") and instance.orderitems.count() > 0:
            return Response(
                {"error": "Cannot delete menu item with existing orders."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        return super().destroy(request, *args, **kwargs)


class MenuItemImageViewSet(ModelViewSet):
    serializer_class = MenuItemImageSerializer

    def get_serializer_context(self):
        return {"menu_item_id": self.kwargs["pk"]}

    def get_queryset(self):
        print(f"Menu Item pk {self.kwargs['pk']}")
        return MenuItemImage.objects.filter(menu_item_id=self.kwargs["pk"])


class MenuCategoryListView(generics.ListAPIView):
    filter_backends = [
        DjangoFilterBackend,
        filters.SearchFilter,
        filters.OrderingFilter,
    ]
    filterset_fields = ["restaurant", "is_active"]
    search_fields = ["name", "description"]
    ordering_fields = ["position", "name", "created_at"]
    ordering = ["position", "name"]
    permission_classes = [AllowAny]

    def get_queryset(self):
        queryset = MenuCategory.objects.annotate(
            items_count=Count("items", filter=Q(items__is_available=True))
        )

        return queryset

    def get_serializer_class(self):
        if self.request.query_params.get("detailed") == "true":
            return MenuCategorySerializer
        return MenuCategoryListSerializer

    def get_serializer_context(self):
        """Pass request context to serializer"""
        context = super().get_serializer_context()
        context["request"] = self.request
        return context


class MenuCategoryDetailView(generics.RetrieveAPIView):
    serializer_class = MenuCategorySerializer
    permission_classes = [AllowAny]

    def get_queryset(self):
        queryset = MenuCategory.objects.annotate(
            items_count=Count("items", filter=Q(items__is_available=True))
        )

        return queryset

    def get_serializer_context(self):
        """Pass request context to serializer"""
        context = super().get_serializer_context()
        context["request"] = self.request
        return context


class MenuCategoryListCreateView(generics.ListCreateAPIView):
    filter_backends = [
        DjangoFilterBackend,
        filters.SearchFilter,
        filters.OrderingFilter,
    ]
    filterset_fields = ["restaurant", "is_active"]
    search_fields = ["name", "description"]
    ordering_fields = ["position", "name", "created_at"]
    ordering = ["position", "name"]
    permission_classes = [IsAdminOrRestaurantOwner]

    def get_queryset(self):
        queryset = MenuCategory.objects.annotate(
            items_count=Count("items", filter=Q(items__is_available=True))
        )

        if (
            hasattr(self.request.user, "restaurant_profile")
            and not self.request.user.is_staff
        ):
            queryset = queryset.filter(restaurant=self.request.user.restaurant_profile)

        restaurant_id = self.request.query_params.get("restaurant_id")
        if restaurant_id:
            queryset = queryset.filter(restaurant_id=restaurant_id)

        return queryset

    def get_serializer_class(self):
        if self.request.query_params.get("detailed") == "true":
            return MenuCategorySerializer
        return MenuCategoryListSerializer

    def get_serializer_context(self):
        """Pass request context to serializer"""
        context = super().get_serializer_context()
        context["request"] = self.request
        return context


class MenuCategoryRetrieveUpdateDestroyView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = MenuCategorySerializer
    permission_classes = [IsOwnerOrReadOnly]

    def get_queryset(self):
        queryset = MenuCategory.objects.annotate(
            items_count=Count("items", filter=Q(items__is_available=True))
        )

        if (
            hasattr(self.request.user, "restaurant_profile")
            and not self.request.user.is_staff
        ):
            queryset = queryset.filter(restaurant=self.request.user.restaurant_profile)

        return queryset

    def get_serializer_context(self):
        """Pass request context to serializer"""
        context = super().get_serializer_context()
        context["request"] = self.request
        return context

    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()

        if instance.items.count() > 0:
            return Response(
                {"error": "Cannot delete category with existing menu items."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        return super().destroy(request, *args, **kwargs)


class MenuCategoryImageViewSet(ModelViewSet):
    serializer_class = MenuCategoryImageSerializer

    def get_serializer_context(self):
        return {"category_id": self.kwargs["category_id"]}

    def get_queryset(self):
        print(f"Menu Category pk {self.kwargs['category_id']}")
        return MenuCategoryImage.objects.filter(category_id=self.kwargs["category_id"])


class RestaurantListView(generics.ListAPIView):
    """
    Public view to list all available restaurants
    """

    serializer_class = RestaurantProfileSerializer
    permission_classes = [AllowAny]
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ["restaurant_name", "address"]
    ordering_fields = ["restaurant_name", "rating", "created_at"]
    ordering = ["restaurant_name"]

    def get_queryset(self):
        return (
            RestaurantProfile.objects.filter(is_approved=True, is_active=True)
            .annotate(
                menu_items_count=Count(
                    "menu_items", filter=Q(menu_items__is_available=True)
                ),
                categories_count=Count(
                    "categories", filter=Q(categories__is_active=True)
                ),
                avg_rating=Avg("rating"),
            )
            .select_related("user")
        )


class RestaurantDetailView(generics.RetrieveAPIView):
    """
    Public view to get restaurant details with menu
    """

    serializer_class = RestaurantProfileSerializer
    permission_classes = [AllowAny]

    def get_queryset(self):
        return (
            RestaurantProfile.objects.filter(is_approved=True, is_active=True)
            .prefetch_related("categories__items__promotions", "promotions")
            .select_related("user")
        )
