from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import filters, generics, permissions

from .models import RestaurantReview
from .permissions import IsReviewOwnerOrReadOnly
from .serializers import RestaurantReviewSerializer

class RestaurantReviewListCreateView(generics.ListCreateAPIView):
    serializer_class = RestaurantReviewSerializer
    permission_classes = [permissions.IsAuthenticated]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter]
    filterset_fields = ["rating"]
    search_fields = ["comment", "customer__user__username", "customer__user__first_name", "customer__user__last_name"]

    def get_queryset(self):
        queryset = RestaurantReview.objects.select_related(
            'customer__user', 'restaurant'
        ).all()
        owner_profile = getattr(self.request.user, "restaurant_profile", None)
        staff_profile = getattr(self.request.user, "restaurant_staff_profile", None)
        if owner_profile and not self.request.user.is_staff:
            queryset = queryset.filter(restaurant=owner_profile)
        elif staff_profile and staff_profile.is_active:
            queryset = queryset.filter(restaurant=staff_profile.restaurant)
        restaurant_id = self.request.query_params.get('restaurant')
        if restaurant_id:
            queryset = queryset.filter(restaurant_id=restaurant_id)
        return queryset

    def perform_create(self, serializer):
        serializer.save(customer=self.request.user.customer_profile)

class RestaurantReviewDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = RestaurantReview.objects.all()
    serializer_class = RestaurantReviewSerializer
    permission_classes = [permissions.IsAuthenticated, IsReviewOwnerOrReadOnly]

    def get_queryset(self):
        queryset = super().get_queryset().select_related("customer__user", "restaurant")
        owner_profile = getattr(self.request.user, "restaurant_profile", None)
        if owner_profile and not self.request.user.is_staff:
            return queryset.filter(restaurant=owner_profile)
        staff_profile = getattr(self.request.user, "restaurant_staff_profile", None)
        if staff_profile and staff_profile.is_active:
            return queryset.filter(restaurant=staff_profile.restaurant)
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


class MenuItemOnPromotionListView(generics.ListAPIView):
    """GET /items/on-promotion/ — items with an active, in-window promotion."""
    serializer_class = MenuItemSerializer
    permission_classes = [AllowAny]
    filter_backends = [
        DjangoFilterBackend,
        filters.SearchFilter,
        filters.OrderingFilter,
    ]
    filterset_fields = ["restaurant", "category", "is_available"]
    search_fields = ["title", "description"]
    ordering_fields = ["price", "title", "created_at"]
    ordering = ["category__position", "title"]

    def get_queryset(self):
        now = timezone.now()
        queryset = (
            MenuItem.objects.select_related('restaurant', 'category')
            .prefetch_related('images', 'promotions')
            .filter(
                promotions__is_active=True,
                promotions__start_date__lte=now,
                promotions__end_date__gte=now,
            )
            .distinct()
        )
        if (
            hasattr(self.request.user, "restaurant_profile")
            and not self.request.user.is_staff
        ):
            return queryset.filter(restaurant=self.request.user.restaurant_profile)
        # public access: only approved restaurants
        return queryset.filter(
            restaurant__is_approved=True, restaurant__is_active=True
        )


class MenuItemAddPromotionView(generics.GenericAPIView):
    """POST /items/{id}/add-promotion/ — attach an own-restaurant promotion."""
    queryset = MenuItem.objects.select_related('restaurant', 'category').prefetch_related('images', 'promotions').all()
    serializer_class = MenuItemSerializer
    permission_classes = [IsOwnerOrReadOnly, IsManagerOrReadOnly]

    def post(self, request, pk=None):
        menu_item = self.get_object()
        promotion_id = request.data.get("promotion_id")
        try:
            promotion = Promotion.objects.get(
                id=promotion_id, restaurant=menu_item.restaurant
            )
        except (Promotion.DoesNotExist, ValueError, TypeError):
            return Response(
                {"error": "Promotion not found or does not belong to this restaurant"},
                status=status.HTTP_404_NOT_FOUND,
            )
        menu_item.promotions.add(promotion)
        serializer = self.get_serializer(menu_item)
        return Response(serializer.data)


class MenuItemRemovePromotionView(generics.GenericAPIView):
    """POST /items/{id}/remove-promotion/ — detach a promotion."""
    queryset = MenuItem.objects.select_related('restaurant', 'category').prefetch_related('images', 'promotions').all()
    serializer_class = MenuItemSerializer
    permission_classes = [IsOwnerOrReadOnly, IsManagerOrReadOnly]

    def post(self, request, pk=None):
        menu_item = self.get_object()
        promotion_id = request.data.get("promotion_id")
        try:
            promotion = Promotion.objects.get(id=promotion_id)
        except (Promotion.DoesNotExist, ValueError, TypeError):
            return Response(
                {"error": "Promotion not found"}, status=status.HTTP_404_NOT_FOUND
            )
        menu_item.promotions.remove(promotion)
        serializer = self.get_serializer(menu_item)
        return Response(serializer.data)


class MenuItemImageViewSet(ModelViewSet):
    serializer_class = MenuItemImageSerializer

    def get_serializer_context(self):
        return {"menu_item_id": self.kwargs["pk"]}

    def get_queryset(self):
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
                    "menu_items",
                    filter=Q(menu_items__is_available=True),
                    distinct=True,
                ),
                categories_count=Count(
                    "categories",
                    filter=Q(categories__is_active=True),
                    distinct=True,
                ),
                avg_rating=Avg("reviews__rating", distinct=True),
            )
            .select_related("user")
            .distinct()
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
            .annotate(
                menu_items_count=Count(
                    "menu_items",
                    filter=Q(menu_items__is_available=True),
                    distinct=True,
                ),
                categories_count=Count(
                    "categories",
                    filter=Q(categories__is_active=True),
                    distinct=True,
                ),
                avg_rating=Avg("reviews__rating", distinct=True),
            )
            .prefetch_related("categories__items__promotions", "promotions")
            .select_related("user")
            .distinct()
        )
