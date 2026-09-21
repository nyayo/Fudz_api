"""restaurants API tests: public browsing, ownership scoping, permissions."""
import pytest
from datetime import timedelta
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient

from factories import (
    MenuCategoryFactory,
    MenuItemFactory,
    PromotionFactory,
    RestaurantProfileFactory,
)

pytestmark = [pytest.mark.django_db, pytest.mark.views]

REST = "/api/v1/restaurants"


def _client_for(user):
    client = APIClient()
    client.force_authenticate(user)
    return client


class TestPublicRestaurantBrowsing:
    def test_list_shows_only_approved_active(self, anon_api):
        visible = RestaurantProfileFactory(is_approved=True, is_active=True)
        RestaurantProfileFactory(is_approved=False)
        RestaurantProfileFactory(is_approved=True, is_active=False)
        resp = anon_api.get(f"{REST}/restaurants/")
        names = [r["restaurant_name"] for r in resp.data["results"]]
        assert visible.restaurant_name in names
        assert len(names) == 1

    def test_search(self, anon_api):
        r1 = RestaurantProfileFactory(restaurant_name="Kampala Grill")
        RestaurantProfileFactory(restaurant_name="Entebbe Bites")
        resp = anon_api.get(f"{REST}/restaurants/", {"search": "Kampala"})
        assert [r["restaurant_name"] for r in resp.data["results"]] == ["Kampala Grill"]

    def test_detail(self, anon_api):
        r = RestaurantProfileFactory()
        resp = anon_api.get(f"{REST}/restaurants/{r.id}/")
        assert resp.status_code == 200
        assert resp.data["restaurant_name"] == r.restaurant_name

    def test_unapproved_detail_404(self, anon_api):
        r = RestaurantProfileFactory(is_approved=False)
        resp = anon_api.get(f"{REST}/restaurants/{r.id}/")
        assert resp.status_code == status.HTTP_404_NOT_FOUND


class TestMenuItemPermissions:
    def test_public_list_shows_only_approved_restaurants_items(self, anon_api):
        approved = RestaurantProfileFactory(is_approved=True)
        unapproved = RestaurantProfileFactory(is_approved=False)
        approved_cat = MenuCategoryFactory(restaurant=approved)
        unapproved_cat = MenuCategoryFactory(restaurant=unapproved)
        MenuItemFactory(category=approved_cat)
        MenuItemFactory(category=unapproved_cat)
        resp = anon_api.get(f"{REST}/items/")
        ids = {i["id"] for i in resp.data["results"]}
        assert approved.menu_items.first().id in ids
        assert unapproved.menu_items.first().id not in ids

    def test_anon_cannot_create_menu_item(self, anon_api):
        category = MenuCategoryFactory()
        resp = anon_api.post(
            f"{REST}/items/",
            {"title": "X", "price": "1000", "category": category.id},
            format="json",
        )
        assert resp.status_code in (status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN)

    def test_customer_cannot_create_menu_item(self, customer_api):
        category = MenuCategoryFactory()
        resp = customer_api.post(
            f"{REST}/items/",
            {"title": "X", "price": "1000", "category": category.id},
            format="json",
        )
        assert resp.status_code == status.HTTP_403_FORBIDDEN

    def test_restaurant_owner_creates_own_item(self, restaurant_api, restaurant_user):
        """Permission fix regression: owners (user_type='restaurant') may
        create menu items without being in a 'Manager' group."""
        category = MenuCategoryFactory(restaurant=restaurant_user.restaurant_profile)
        resp = restaurant_api.post(
            f"{REST}/items/",
            {"title": "Luwombo", "price": "12000", "category": category.id},
            format="json",
        )
        assert resp.status_code == status.HTTP_201_CREATED, resp.data

    def test_staff_in_manager_group_can_create_item(self, restaurant_user, db):
        from django.contrib.auth.models import Group

        Group.objects.get_or_create(name="Manager")
        restaurant_user.groups.add(Group.objects.get(name="Manager"))
        category = MenuCategoryFactory(restaurant=restaurant_user.restaurant_profile)
        resp = _client_for(restaurant_user).post(
            f"{REST}/items/",
            {"title": "Luwombo", "price": "12000", "category": category.id},
            format="json",
        )
        assert resp.status_code == status.HTTP_201_CREATED, resp.data

    def test_owner_cannot_update_other_restaurants_item(self, restaurant_user, db):
        foreign_item = MenuItemFactory()  # other restaurant
        # NOTE: MenuItemRetrieveUpdateDestroyView does NOT scope the queryset
        # to the owner's restaurant on the non-list path — the denial comes
        # from IsManagerOrReadOnly (403) rather than 404 scoping.
        resp = _client_for(restaurant_user).patch(
            f"{REST}/items/{foreign_item.id}/", {"price": "1"}, format="json"
        )
        assert resp.status_code in (status.HTTP_403_FORBIDDEN, status.HTTP_404_NOT_FOUND)

    def test_owner_cannot_delete_item_with_orders(self, restaurant_user, db):
        from django.contrib.auth.models import Group
        from factories import OrderFactory, OrderItemFactory

        Group.objects.get_or_create(name="Manager")
        restaurant_user.groups.add(Group.objects.get(name="Manager"))
        category = MenuCategoryFactory(restaurant=restaurant_user.restaurant_profile)
        item = MenuItemFactory(category=category)
        OrderItemFactory(order=OrderFactory(restaurant=restaurant_user.restaurant_profile), menu_item=item, unit_price=item.price)
        resp = _client_for(restaurant_user).delete(f"{REST}/items/{item.id}/")
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert "existing orders" in resp.data["error"]

    def test_owner_can_delete_item_without_orders(self, restaurant_user, db):
        from django.contrib.auth.models import Group

        Group.objects.get_or_create(name="Manager")
        restaurant_user.groups.add(Group.objects.get(name="Manager"))
        category = MenuCategoryFactory(restaurant=restaurant_user.restaurant_profile)
        item = MenuItemFactory(category=category)
        resp = _client_for(restaurant_user).delete(f"{REST}/items/{item.id}/")
        assert resp.status_code == status.HTTP_204_NO_CONTENT

    def test_filtering_search_ordering(self, anon_api):
        approved = RestaurantProfileFactory(is_approved=True)
        cat = MenuCategoryFactory(restaurant=approved)
        i1 = MenuItemFactory(category=cat, title="A Rolex", price=5000)
        i2 = MenuItemFactory(category=cat, title="B Muchomo", price=15000)
        resp = anon_api.get(f"{REST}/items/", {"search": "Rolex"})
        assert [i["id"] for i in resp.data["results"]] == [i1.id]
        resp = anon_api.get(f"{REST}/items/", {"ordering": "price"})
        prices = [float(i["price"]) for i in resp.data["results"]]
        assert prices == sorted(prices)

    def test_add_promotion_action(self, restaurant_api, restaurant_user):
        """Routes added (restaurants/urls.py): add/remove-promotion now live."""
        category = MenuCategoryFactory(restaurant=restaurant_user.restaurant_profile)
        item = MenuItemFactory(category=category)
        promo = PromotionFactory(restaurant=restaurant_user.restaurant_profile)
        resp = restaurant_api.post(f"{REST}/items/{item.id}/add-promotion/", {"promotion_id": promo.id}, format="json")
        assert resp.status_code == 200
        assert item.promotions.filter(pk=promo.pk).exists()

    def test_add_promotion_foreign_promotion_404(self, restaurant_api, restaurant_user):
        category = MenuCategoryFactory(restaurant=restaurant_user.restaurant_profile)
        item = MenuItemFactory(category=category)
        promo = PromotionFactory()  # another restaurant's promo
        resp = restaurant_api.post(f"{REST}/items/{item.id}/add-promotion/", {"promotion_id": promo.id}, format="json")
        assert resp.status_code == status.HTTP_404_NOT_FOUND

    def test_remove_promotion_action(self, restaurant_api, restaurant_user):
        category = MenuCategoryFactory(restaurant=restaurant_user.restaurant_profile)
        item = MenuItemFactory(category=category)
        promo = PromotionFactory(restaurant=restaurant_user.restaurant_profile)
        item.promotions.add(promo)
        resp = restaurant_api.post(f"{REST}/items/{item.id}/remove-promotion/", {"promotion_id": promo.id}, format="json")
        assert resp.status_code == 200
        assert not item.promotions.filter(pk=promo.pk).exists()

    def test_on_promotion_action(self, anon_api, db):
        approved = RestaurantProfileFactory(is_approved=True)
        cat = MenuCategoryFactory(restaurant=approved)
        from datetime import timedelta
        from django.utils import timezone

        on_promo = MenuItemFactory(category=cat, title="Promo Special")
        promo = PromotionFactory(
            restaurant=approved, discount=15.0,
            start_date=timezone.now() - timedelta(hours=1),
            end_date=timezone.now() + timedelta(hours=1),
        )
        on_promo.promotions.add(promo)
        MenuItemFactory(category=cat, title="Plain Special")

        resp = anon_api.get(f"{REST}/items/on-promotion/")
        assert resp.status_code == 200
        rows = resp.data["results"] if isinstance(resp.data, dict) else resp.data
        titles = {r["title"] for r in rows}
        assert "Promo Special" in titles
        assert "Plain Special" not in titles


class TestMenuCategoryPermissions:
    def test_anon_can_list_categories(self, anon_api):
        MenuCategoryFactory()
        resp = anon_api.get(f"{REST}/categories/")
        assert resp.status_code == 200

    def test_anon_cannot_create_category(self, anon_api):
        r = RestaurantProfileFactory()
        resp = anon_api.post(f"{REST}/restaurants/{r.id}/categories/", {"name": "C"}, format="json")
        assert resp.status_code in (status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN)

    def test_owner_lists_only_own_categories(self, restaurant_user, db):
        mine = MenuCategoryFactory(restaurant=restaurant_user.restaurant_profile)
        MenuCategoryFactory()
        resp = _client_for(restaurant_user).get(
            f"{REST}/restaurants/{restaurant_user.restaurant_profile.id}/categories/"
        )
        ids = [c["id"] for c in resp.data["results"]]
        assert ids == [mine.id]

    def test_owner_creates_category(self, restaurant_api, restaurant_user):
        resp = restaurant_api.post(
            f"{REST}/restaurants/{restaurant_user.restaurant_profile.id}/categories/",
            {"name": "Starters"},
            format="json",
        )
        assert resp.status_code == status.HTTP_201_CREATED, resp.data

    def test_delete_category_with_items_400(self, restaurant_api, restaurant_user):
        cat = MenuCategoryFactory(restaurant=restaurant_user.restaurant_profile)
        MenuItemFactory(category=cat)
        resp = restaurant_api.delete(
            f"{REST}/restaurants/{restaurant_user.restaurant_profile.id}/categories/{cat.id}/"
        )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST


class TestPromotionPermissions:
    def test_public_can_read_promotions(self, anon_api):
        PromotionFactory()
        resp = anon_api.get(f"{REST}/promotions/")
        assert resp.status_code == 200

    def test_anon_cannot_create_promotion(self, anon_api):
        resp = anon_api.post(f"{REST}/promotions/", {}, format="json")
        assert resp.status_code in (status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN)

    def test_owner_scoped_to_own_promotions(self, restaurant_user, db):
        mine = PromotionFactory(restaurant=restaurant_user.restaurant_profile)
        PromotionFactory()
        resp = _client_for(restaurant_user).get(f"{REST}/promotions/")
        ids = [p["id"] for p in resp.data["results"]]
        assert ids == [mine.id]

    def test_end_date_before_start_400(self, restaurant_api, restaurant_user):
        resp = restaurant_api.post(
            f"{REST}/promotions/",
            {
                "restaurant": restaurant_user.restaurant_profile.id,
                "name": "Bad",
                "description": "Bad promo",
                "discount": 10,
                "start_date": timezone.now() + timedelta(days=2),
                "end_date": timezone.now() + timedelta(days=1),
            },
            format="json",
        )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert "End date must be after start date" in str(resp.data)

    def test_active_action_filters_window(self, anon_api):
        active = PromotionFactory(
            start_date=timezone.now() - timedelta(hours=1),
            end_date=timezone.now() + timedelta(hours=1),
        )
        PromotionFactory(
            start_date=timezone.now() - timedelta(days=2),
            end_date=timezone.now() - timedelta(days=1),
        )
        resp = anon_api.get(f"{REST}/promotions/active/")
        rows = resp.data["results"] if isinstance(resp.data, dict) else resp.data
        ids = [p["id"] for p in rows]
        assert ids == [active.id]

    def test_toggle_active(self, restaurant_api, restaurant_user):
        promo = PromotionFactory(restaurant=restaurant_user.restaurant_profile, is_active=True)
        resp = restaurant_api.post(f"{REST}/promotions/{promo.id}/toggle_active/")
        assert resp.status_code == 200
        promo.refresh_from_db()
        assert promo.is_active is False
