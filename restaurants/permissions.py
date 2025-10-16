from rest_framework import permissions
from rest_framework.permissions import BasePermission


class IsOwnerOrReadOnly(BasePermission):
    """
    Custom permission to only allow owners of an object to edit it.
    """
    def has_object_permission(self, request, view, obj):
        if request.method in permissions.SAFE_METHODS:
            return True
        
        if hasattr(obj, 'restaurant'):
            return obj.restaurant.user == request.user
        
        return False


class IsAdminOrRestaurantOwner(BasePermission):
    """
    Permission to allow only admin users or restaurant owners to create/modify.
    """
    def has_permission(self, request, view):
        if request.method in permissions.SAFE_METHODS:
            return True
        
        if not request.user.is_authenticated:
            return False
            
        return (
            request.user.is_staff or 
            getattr(request.user, 'user_type', None) == 'restaurant'
        )
    
    def has_object_permission(self, request, view, obj):
        if request.method in permissions.SAFE_METHODS:
            return True
            
        if not request.user.is_authenticated:
            return False

        if request.user.is_staff:
            return True
            
        if hasattr(obj, 'restaurant'):
            return obj.restaurant.user == request.user
            
        return False