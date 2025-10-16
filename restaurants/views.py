from django.db.models import Count, Q, Avg

from rest_framework import status, generics, filters
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from rest_framework.viewsets import ModelViewSet
from django_filters.rest_framework import DjangoFilterBackend

from users.models import RestaurantProfile
from .models import MenuCategoryImage, MenuItem, MenuCategory, MenuItemImage
from .serializers import (
    MenuCategoryImageSerializer, MenuCategorySerializer, MenuCategoryListSerializer, MenuItemImageSerializer, 
    MenuItemSerializer, RestaurantProfileSerializer
)
from .permissions import IsAdminOrRestaurantOwner, IsOwnerOrReadOnly


class MenuItemListCreateView(generics.ListCreateAPIView):
    queryset = MenuItem.objects.select_related('restaurant', 'category', 'images').all()
    serializer_class = MenuItemSerializer
    permission_classes = [IsAdminOrRestaurantOwner]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['restaurant', 'category', 'is_available', 'is_featured']
    search_fields = ['title', 'description']
    ordering_fields = ['price', 'title', 'created_at']
    ordering = ['category__position', 'title']
    
    def get_queryset(self):
        queryset = super().get_queryset()
        
        if (hasattr(self.request.user, 'restaurant_profile') and 
            not self.request.user.is_staff):
            queryset = queryset.filter(restaurant=self.request.user.restaurant_profile)
        
        restaurant_id = self.request.query_params.get('restaurant_id')
        if restaurant_id:
            queryset = queryset.filter(restaurant_id=restaurant_id)
            
        return queryset
    
    def get_serializer_context(self):
        """Pass request context to serializer"""
        context = super().get_serializer_context()
        context['request'] = self.request
        return context
    
    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        
        if hasattr(instance, 'orderitems') and instance.orderitems.count() > 0:
            return Response(
                {"error": "Cannot delete menu item with existing orders."},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        return super().destroy(request, *args, **kwargs)


class MenuItemRetrieveUpdateDestroyView(generics.RetrieveUpdateDestroyAPIView):
    queryset = MenuItem.objects.select_related('restaurant', 'category', 'images').all()
    serializer_class = MenuItemSerializer
    permission_classes = [IsOwnerOrReadOnly]
    
    def get_queryset(self):
        queryset = super().get_queryset()
        
        if (hasattr(self.request.user, 'restaurant_profile') and 
            not self.request.user.is_staff):
            queryset = queryset.filter(restaurant=self.request.user.restaurant_profile)
            
        return queryset
    
    def get_serializer_context(self):
        """Pass request context to serializer"""
        context = super().get_serializer_context()
        context['request'] = self.request
        return context
    
    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        
        if hasattr(instance, 'orderitems') and instance.orderitems.count() > 0:
            return Response(
                {"error": "Cannot delete menu item with existing orders."},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        return super().destroy(request, *args, **kwargs)

class MenuItemImageViewSet(ModelViewSet):
    serializer_class = MenuItemImageSerializer
    
    def get_serializer_context(self):
        return {'menu_item_id': self.kwargs['pk']}
    
    def get_queryset(self):
        print(f"Menu Item pk {self.kwargs['pk']}")
        return MenuItemImage.objects.filter(menu_item_id=self.kwargs['pk'])


class MenuCategoryListCreateView(generics.ListCreateAPIView):
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['restaurant', 'is_active']
    search_fields = ['name', 'description']
    ordering_fields = ['position', 'name', 'created_at']
    ordering = ['position', 'name']
    permission_classes = [IsAdminOrRestaurantOwner]
    
    def get_queryset(self):
        queryset = MenuCategory.objects.annotate(
            items_count=Count('items', filter=Q(items__is_available=True))
        )
        
        if (hasattr(self.request.user, 'restaurant_profile') and 
            not self.request.user.is_staff):
            queryset = queryset.filter(restaurant=self.request.user.restaurant_profile)
        
        restaurant_id = self.request.query_params.get('restaurant_id')
        if restaurant_id:
            queryset = queryset.filter(restaurant_id=restaurant_id)
            
        return queryset
    
    def get_serializer_class(self):
        if self.request.query_params.get('detailed') == 'true':
            return MenuCategorySerializer
        return MenuCategoryListSerializer
    
    def get_serializer_context(self):
        """Pass request context to serializer"""
        context = super().get_serializer_context()
        context['request'] = self.request
        return context


class MenuCategoryRetrieveUpdateDestroyView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = MenuCategorySerializer
    permission_classes = [IsOwnerOrReadOnly]
    
    def get_queryset(self):
        queryset = MenuCategory.objects.annotate(
            items_count=Count('items', filter=Q(items__is_available=True))
        )
        
        if (hasattr(self.request.user, 'restaurant_profile') and 
            not self.request.user.is_staff):
            queryset = queryset.filter(restaurant=self.request.user.restaurant_profile)
            
        return queryset
    
    def get_serializer_context(self):
        """Pass request context to serializer"""
        context = super().get_serializer_context()
        context['request'] = self.request
        return context
    
    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        
        if instance.items.count() > 0:
            return Response(
                {"error": "Cannot delete category with existing menu items."},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        return super().destroy(request, *args, **kwargs)


class MenuCategoryImageViewSet(ModelViewSet):
    serializer_class = MenuCategoryImageSerializer

    def get_serializer_context(self):
        return {'category_id': self.kwargs['category_id']}

    def get_queryset(self):
        print(f"Menu Category pk {self.kwargs['category_id']}")
        return MenuCategoryImage.objects.filter(category_id=self.kwargs['category_id'])


class RestaurantListView(generics.ListAPIView):
    """
    Public view to list all available restaurants
    """
    serializer_class = RestaurantProfileSerializer
    permission_classes = [AllowAny]
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['restaurant_name', 'address']
    ordering_fields = ['restaurant_name', 'rating', 'created_at']
    ordering = ['restaurant_name']
    
    def get_queryset(self):
        return RestaurantProfile.objects.filter(
            is_approved=True,
            is_active=True
        ).annotate(
            menu_items_count=Count('menu_items', filter=Q(menu_items__is_available=True)),
            categories_count=Count('categories', filter=Q(categories__is_active=True)),
            avg_rating=Avg('rating')
        ).select_related('user')

    
class RestaurantDetailView(generics.RetrieveAPIView):
    """
    Public view to get restaurant details with menu
    """
    serializer_class = RestaurantProfileSerializer
    permission_classes = [AllowAny]
    
    def get_queryset(self):
        return RestaurantProfile.objects.filter(
            is_approved=True,
            is_active=True
        ).prefetch_related(
            'categories__items__promotions',
            'promotions'
        ).select_related('user')   
    
