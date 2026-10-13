from rest_framework.permissions import BasePermission, SAFE_METHODS

class IsReviewOwnerOrReadOnly(BasePermission):
    """Customers may edit their review; restaurant owners may reply to reviews."""
    
    def has_object_permission(self, request, view, obj):
        if request.method in SAFE_METHODS:
            return True
        owner_profile = getattr(request.user, "restaurant_profile", None)
        if request.method in ("PATCH", "PUT") and owner_profile:
            return obj.restaurant_id == owner_profile.id
        staff_profile = getattr(request.user, "restaurant_staff_profile", None)
        if request.method in ("PATCH", "PUT") and staff_profile and staff_profile.is_active:
            return obj.restaurant_id == staff_profile.restaurant_id
        return obj.customer.user == request.user or request.user.is_staff
