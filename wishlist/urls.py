from django.urls import path
from .views import WishlistListView, AddToWishlistView, RemoveFromWishlistView

urlpatterns = [
    path('', WishlistListView.as_view(), name='wishlist'),
    path('add/', AddToWishlistView.as_view(), name='wishlist-add'),
    path('remove/<int:menu_item_id>/', RemoveFromWishlistView.as_view(), name='wishlist-remove'),
]
