from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from drf_spectacular.utils import extend_schema, inline_serializer
from rest_framework import serializers as drf_serializers

from .models import Wishlist, WishlistItem
from .serializers import WishlistItemSerializer
from restaurants.models import MenuItem

class WishlistListView(generics.ListAPIView):
    serializer_class = WishlistItemSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        wishlist, _ = Wishlist.objects.get_or_create(customer=self.request.user.customer_profile)
        return wishlist.items.select_related('menu_item')

@extend_schema(
    request=inline_serializer(
        name='AddToWishlistRequest',
        fields={
            'menu_item_id': drf_serializers.IntegerField(),
        }
    ),
    responses={
        201: WishlistItemSerializer,
        400: inline_serializer(
            name='WishlistErrorResponse',
            fields={'detail': drf_serializers.CharField()}
        )
    }
)
class AddToWishlistView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        customer = request.user.customer_profile
        wishlist, _ = Wishlist.objects.get_or_create(customer=customer)
        menu_item_id = request.data.get("menu_item_id")

        try:
            menu_item = MenuItem.objects.get(id=menu_item_id)
        except MenuItem.DoesNotExist:
            return Response({"error": "Menu item not found"}, status=status.HTTP_404_NOT_FOUND)

        item, created = WishlistItem.objects.get_or_create(
            wishlist=wishlist,
            menu_item=menu_item
        )
        if not created:
            return Response({"detail": "Item already in wishlist."}, status=status.HTTP_400_BAD_REQUEST)

        serializer = WishlistItemSerializer(item)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

@extend_schema(
    responses={
        204: None,
        404: inline_serializer(
            name='WishlistNotFoundResponse',
            fields={'detail': drf_serializers.CharField()}
        )
    }
)
class RemoveFromWishlistView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def delete(self, request, menu_item_id):
        try:
            wishlist = Wishlist.objects.get(customer=request.user.customer_profile)
        except Wishlist.DoesNotExist:
            return Response(
                {"detail": "Wishlist not found."},
                status=status.HTTP_404_NOT_FOUND
            )
        try:
            item = WishlistItem.objects.get(wishlist=wishlist, menu_item_id=menu_item_id)
            item.delete()
            return Response({"detail": "Removed from wishlist."}, status=status.HTTP_204_NO_CONTENT)
        except WishlistItem.DoesNotExist:
            return Response({"detail": "Item not found in wishlist."}, status=status.HTTP_404_NOT_FOUND)
