from rest_framework import generics, permissions

from .models import RestaurantReview
from .serializers import RestaurantReviewSerializer

class RestaurantReviewListCreateView(generics.ListCreateAPIView):
    queryset = RestaurantReview.objects.all()
    serializer_class = RestaurantReviewSerializer
    permission_classes = [permissions.IsAuthenticated]

    def perform_create(self, serializer):
        serializer.save(customer=self.request.user.customer_profile)

class RestaurantReviewDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = RestaurantReview.objects.all()
    serializer_class = RestaurantReviewSerializer
    permission_classes = [permissions.IsAuthenticated]
