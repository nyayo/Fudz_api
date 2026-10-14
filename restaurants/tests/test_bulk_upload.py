"""Regression tests for the restaurant-scoped menu-item bulk upsert API."""

import pytest
from rest_framework import status

from factories import MenuCategoryFactory, MenuItemFactory, RestaurantProfileFactory

pytestmark = [pytest.mark.django_db, pytest.mark.views]

REST = "/api/v1/restaurants"


class TestMenuItemBulkUpsert:
    def test_owner_import_resolves_restaurant_and_creates_or_updates_rows(
        self, restaurant_api, restaurant_user
    ):
        restaurant = restaurant_user.restaurant_profile
        category = MenuCategoryFactory(restaurant=restaurant)
        by_id = MenuItemFactory(category=category, title="Stew")
        by_title = MenuItemFactory(category=category, title="Matoke")

        response = restaurant_api.post(
            f"{REST}/items/bulk/",
            {
                "items": [
                    {
                        "title": "New item",
                        "description": "Created from CSV",
                        "category": category.id,
                        "price": "3500.00",
                        "is_available": True,
                        "is_featured": False,
                        "prep_time_minutes": 20,
                        "allergens": "",
                    },
                    {
                        "id": by_id.id,
                        "title": "Stew special",
                        "description": "Updated by ID",
                        "category": category.id,
                        "price": "4200.00",
                        "is_available": True,
                        "is_featured": False,
                        "prep_time_minutes": 25,
                        "allergens": "",
                    },
                    {
                        "title": "Matoke",
                        "description": "Updated by matching title",
                        "category": category.id,
                        "price": "2800.00",
                        "is_available": True,
                        "is_featured": False,
                        "prep_time_minutes": 15,
                        "allergens": "",
                    },
                ]
            },
            format="json",
        )

        assert response.status_code == status.HTTP_200_OK, response.data
        assert response.data["restaurant"] == restaurant.id
        assert response.data["created"] == 1
        assert response.data["updated"] == 2
        assert response.data["failed"] == 0

        by_id.refresh_from_db()
        by_title.refresh_from_db()
        assert by_id.title == "Stew special"
        assert by_id.restaurant_id == restaurant.id
        assert by_title.description == "Updated by matching title"
        created = restaurant.menu_items.get(title="New item")
        assert created.restaurant_id == restaurant.id

    def test_owner_cannot_import_into_another_restaurant(
        self, restaurant_api, restaurant_user
    ):
        other = RestaurantProfileFactory()
        category = MenuCategoryFactory(restaurant=other)
        response = restaurant_api.post(
            f"{REST}/items/bulk/",
            {
                "restaurant": other.id,
                "items": [
                    {
                        "title": "Foreign item",
                        "category": category.id,
                        "price": "1000.00",
                        "is_available": True,
                        "is_featured": False,
                    }
                ],
            },
            format="json",
        )

        assert response.status_code == status.HTTP_403_FORBIDDEN
        assert not other.menu_items.filter(title="Foreign item").exists()
