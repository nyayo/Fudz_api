from django.urls import path
from .views import RestaurantReviewListCreateView, RestaurantReviewDetailView

urlpatterns = [
    path('', RestaurantReviewListCreateView.as_view(), name='review-list'),
    path('<int:pk>/', RestaurantReviewDetailView.as_view(), name='review-detail'),
]
