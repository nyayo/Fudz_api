"""Restaurant-scoped menu-item bulk create/update endpoint."""

from django.core.exceptions import ValidationError as DjangoValidationError
from django.db import IntegrityError, transaction
from rest_framework import status
from rest_framework.generics import GenericAPIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from users.models import RestaurantProfile

from .models import MenuItem
from .serializers import MenuItemSerializer


class MenuItemBulkUpsertView(GenericAPIView):
    """Create or update menu items in one restaurant-scoped CSV import.

    A row with an ``id`` updates that item (only if it belongs to the resolved
    restaurant). A row without an ``id`` updates an exact title match in that
    restaurant, or creates the item if no match exists.
    """

    serializer_class = MenuItemSerializer
    permission_classes = [IsAuthenticated]
    max_rows = 500

    def post(self, request, *args, **kwargs):
        restaurant, error_response = self._resolve_restaurant(request)
        if error_response:
            return error_response

        rows = request.data.get("items")
        if not isinstance(rows, list) or not rows:
            return Response(
                {"items": "Provide a non-empty list of menu item rows."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if len(rows) > self.max_rows:
            return Response(
                {"items": f"A single import may contain at most {self.max_rows} rows."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        results = []
        created = 0
        updated = 0

        for index, raw_row in enumerate(rows):
            if not isinstance(raw_row, dict):
                results.append({
                    "index": index,
                    "title": "",
                    "ok": False,
                    "error": "Each row must be an object.",
                })
                continue

            row = dict(raw_row)
            item_id = row.pop("id", None)
            if item_id in (None, ""):
                item_id = None
            else:
                try:
                    item_id = int(item_id)
                    if item_id <= 0:
                        raise ValueError
                except (TypeError, ValueError):
                    results.append({
                        "index": index,
                        "title": str(row.get("title", "")),
                        "ok": False,
                        "error": "Item ID must be a positive integer.",
                    })
                    continue

            title = str(row.get("title", "")).strip()
            if item_id is not None:
                instance = MenuItem.objects.filter(
                    pk=item_id, restaurant=restaurant
                ).first()
                if instance is None:
                    results.append({
                        "index": index,
                        "title": title,
                        "ok": False,
                        "error": "That item ID does not belong to the selected restaurant.",
                    })
                    continue
            else:
                instance = MenuItem.objects.filter(
                    restaurant=restaurant, title=title
                ).first() if title else None

            row["restaurant"] = restaurant.pk
            action = "updated" if instance else "created"

            try:
                with transaction.atomic():
                    serializer = self.get_serializer(
                        instance,
                        data=row,
                        partial=instance is not None,
                    )
                    if not serializer.is_valid():
                        results.append({
                            "index": index,
                            "title": title,
                            "ok": False,
                            "error": serializer.errors,
                        })
                        continue
                    saved = serializer.save(restaurant=restaurant)
                    serialized_item = self.get_serializer(saved).data
            except DjangoValidationError as exc:
                detail = getattr(exc, "message_dict", None) or getattr(exc, "messages", [str(exc)])
                results.append({
                    "index": index,
                    "title": title,
                    "ok": False,
                    "error": detail,
                })
                continue
            except IntegrityError:
                results.append({
                    "index": index,
                    "title": title,
                    "ok": False,
                    "error": "This row conflicts with an existing item. Check the item ID and title.",
                })
                continue

            if action == "created":
                created += 1
            else:
                updated += 1
            results.append({
                "index": index,
                "title": saved.title,
                "ok": True,
                "action": action,
                "item_id": saved.pk,
                "item": serialized_item,
            })

        return Response({
            "restaurant": restaurant.pk,
            "created": created,
            "updated": updated,
            "failed": sum(1 for result in results if not result["ok"]),
            "results": results,
        }, status=status.HTTP_200_OK)

    @staticmethod
    def _resolve_restaurant(request):
        user = request.user
        requested_id = request.data.get("restaurant")

        if user.is_staff:
            if requested_id in (None, ""):
                return None, Response(
                    {"restaurant": "Select a restaurant for this import."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            try:
                restaurant_id = int(requested_id)
            except (TypeError, ValueError):
                return None, Response(
                    {"restaurant": "Restaurant must be a valid ID."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            restaurant = RestaurantProfile.objects.filter(pk=restaurant_id).first()
            if restaurant is None:
                return None, Response(
                    {"restaurant": "Restaurant was not found."},
                    status=status.HTTP_404_NOT_FOUND,
                )
            return restaurant, None

        owner_profile = getattr(user, "restaurant_profile", None)
        staff_profile = getattr(user, "restaurant_staff_profile", None)
        manager_group = user.groups.filter(name="Manager").exists()

        if owner_profile is not None:
            restaurant = owner_profile
        elif staff_profile is not None and staff_profile.is_active and (
            staff_profile.role == "manager" or manager_group
        ):
            restaurant = staff_profile.restaurant
        else:
            return None, Response(
                {"detail": "Only restaurant owners, active managers, or platform admins can import menu items."},
                status=status.HTTP_403_FORBIDDEN,
            )

        if requested_id not in (None, "") and str(requested_id) != str(restaurant.pk):
            return None, Response(
                {"restaurant": "You may only import items for your assigned restaurant."},
                status=status.HTTP_403_FORBIDDEN,
            )
        return restaurant, None
