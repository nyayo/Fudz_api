from django.urls import path
from rest_framework_nested import routers
from . import views


router = routers.DefaultRouter()
router.register('images', views.MenuItemImageViewSet, basename='menuitem-image')
router.register('promotions', views.PromotionViewSet, basename='promotion')

urlpatterns = [
    path('restaurants/', views.RestaurantListView.as_view(), name='restaurant-list'),
    path('restaurants/<int:pk>/', views.RestaurantDetailView.as_view(), name='restaurant-detail'),

    path('restaurants/<int:restaurant_id>/categories/', views.MenuCategoryListCreateView.as_view(), name='restaurant-category-list'),
    path('restaurants/<int:restaurant_id>/categories/<int:pk>/', views.MenuCategoryRetrieveUpdateDestroyView.as_view(), name='restaurant-category-detail'),

    path('restaurants/<int:restaurant_id>/categories/<int:category_id>/items/', views.MenuItemListCreateView.as_view(), name='restaurant-category-items'),
    path('restaurants/<int:restaurant_id>/categories/<int:category_id>/images/', views.MenuCategoryImageViewSet.as_view({'get': 'list', 'post': 'create'}), name='restaurant-category-images'),
    path('restaurants/<int:restaurant_id>/categories/<int:category_id>/items/<int:pk>/', views.MenuItemRetrieveUpdateDestroyView.as_view(), name='restaurant-category-item-detail'),
    path('restaurants/<int:restaurant_id>/categories/<int:category_id>/items/<int:pk>/images/', views.MenuItemImageViewSet.as_view({'get': 'list', 'post': 'create'}), name='restaurant-category-item-images'),

    path('categories/', views.MenuCategoryListView.as_view(), name='menu-categories'),
    path('categories/<int:pk>/', views.MenuCategoryDetailView.as_view(), name='menu-category-detail'),
    
    path('items/', views.MenuItemListCreateView.as_view(), name='menu-items'),
    path('items/<int:pk>/', views.MenuItemRetrieveUpdateDestroyView.as_view(), name='menu-item-detail'),
    path('items/<int:pk>/images/', views.MenuItemImageViewSet.as_view({'get': 'list', 'post': 'create'}), name='menu-item-images'),
] + router.urls
