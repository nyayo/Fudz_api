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
        if owner_profile:
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
        if owner_profile:
            return queryset.filter(restaurant=owner_profile)
        staff_profile = getattr(self.request.user, "restaurant_staff_profile", None)
        if staff_profile and staff_profile.is_active:
            return queryset.filter(restaurant=staff_profile.restaurant)
        return queryset
