from rest_framework.permissions import BasePermission

class IsManagerOrReadOnly(BasePermission):
    """
    Allows only Managers (or Admins) to edit, others can only view.
    """
    def has_permission(self, request, view):
        if request.method in ('GET', 'HEAD', 'OPTIONS'):
            return True
        return (
            request.user.is_authenticated and
            (request.user.is_staff or request.user.groups.filter(name='Manager').exists())
        )


class IsRestaurantOwner(BasePermission):
    """
    Only allow restaurant owners to manage their own staff.
    """
    def has_permission(self, request, view):
        return request.user.is_authenticated and (hasattr(request.user, "restaurant_profile") or request.user.is_staff)