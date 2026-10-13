from django.urls import path
from rest_framework.routers import DefaultRouter
from .views import AdminWishlistItemViewSet, ClearWishlistView, WishlistListView, AddToWishlistView, RemoveFromWishlistView

router = DefaultRouter()
router.register("admin/items", AdminWishlistItemViewSet, basename="admin-wishlist-items")

urlpatterns = [
    path('', WishlistListView.as_view(), name='wishlist'),
    path('add/', AddToWishlistView.as_view(), name='wishlist-add'),
    path('clear/', ClearWishlistView.as_view(), name='wishlist-clear'),
    path('remove/<int:menu_item_id>/', RemoveFromWishlistView.as_view(), name='wishlist-remove'),
] + router.urls
