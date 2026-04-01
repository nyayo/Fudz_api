from rest_framework.permissions import BasePermission, SAFE_METHODS

class IsReviewOwnerOrReadOnly(BasePermission):
    """Only allow review owner to edit/delete"""
    
    def has_object_permission(self, request, view, obj):
        if request.method in SAFE_METHODS:
            return True
        return obj.customer.user == request.user or request.user.is_staff
