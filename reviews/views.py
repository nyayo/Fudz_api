from rest_framework import generics, permissions

from .models import RestaurantReview
from .serializers import RestaurantReviewSerializer

class RestaurantReviewListCreateView(generics.ListCreateAPIView):
    serializer_class = RestaurantReviewSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        queryset = RestaurantReview.objects.select_related(
            'customer__user', 'restaurant'
        ).all()
        restaurant_id = self.request.query_params.get('restaurant')
        if restaurant_id:
            queryset = queryset.filter(restaurant_id=restaurant_id)
        return queryset

    def perform_create(self, serializer):
        serializer.save(customer=self.request.user.customer_profile)

class RestaurantReviewDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = RestaurantReview.objects.all()
    serializer_class = RestaurantReviewSerializer
    permission_classes = [permissions.IsAuthenticated]
