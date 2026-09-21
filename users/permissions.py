from rest_framework.permissions import BasePermission

class IsManagerOrReadOnly(BasePermission):
    """
    Allows write access to staff, Managers group members, or restaurant
    owners; read-only for everyone else.
    """
    def has_permission(self, request, view):
        if request.method in ('GET', 'HEAD', 'OPTIONS'):
            return True
        if not request.user.is_authenticated:
            return False
        if request.user.is_staff:
            return True
        if request.user.groups.filter(name='Manager').exists():
            return True
        # Restaurant owners manage their own menu/categories (object-level
        # queryset scoping in the views keeps them to their own restaurant).
        return getattr(request.user, 'user_type', None) == 'restaurant'


class IsRestaurantOwner(BasePermission):
    """
    Only allow restaurant owners to manage their own staff.
    """
    def has_permission(self, request, view):
        return request.user.is_authenticated and (hasattr(request.user, "restaurant_profile") or request.user.is_staff)