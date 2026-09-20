"""wishlist API tests: add/remove/list, ownership scoping, edge cases."""
import pytest
from rest_framework import status
from rest_framework.test import APIClient

from factories import (
    CustomerProfileFactory,
    MenuItemFactory,
    MenuCategoryFactory,
    RestaurantProfileFactory,
    WishlistFactory,
    WishlistItemFactory,
)
from wishlist.models import Wishlist, WishlistItem

pytestmark = [pytest.mark.django_db, pytest.mark.views]

WISHLIST = "/api/v1/wishlists"


def _client_for(user):
    client = APIClient()
    client.force_authenticate(user)
    return client


class TestWishlistList:
    def test_requires_auth(self, anon_api):
        assert anon_api.get(f"{WISHLIST}/").status_code in (401, 403)

    def test_list_auto_creates_and_scopes_to_owner(self, customer_user, db):
        WishlistItemFactory(wishlist__customer=CustomerProfileFactory())  # someone else's
        resp = _client_for(customer_user).get(f"{WISHLIST}/")
        rows = resp.data["results"] if isinstance(resp.data, dict) else resp.data
        assert rows == []
        assert Wishlist.objects.filter(customer=customer_user.customer_profile).exists()


class TestWishlistAdd:
    def test_add_item(self, customer_user, db):
        category = MenuCategoryFactory(restaurant=RestaurantProfileFactory())
        item = MenuItemFactory(category=category)
        resp = _client_for(customer_user).post(
            f"{WISHLIST}/add/", {"menu_item_id": item.id}, format="json"
        )
        assert resp.status_code == status.HTTP_201_CREATED
        assert WishlistItem.objects.filter(
            wishlist__customer=customer_user.customer_profile, menu_item=item
        ).exists()

    def test_add_unknown_item_404(self, customer_user, db):
        resp = _client_for(customer_user).post(
            f"{WISHLIST}/add/", {"menu_item_id": 987654321}, format="json"
        )
        assert resp.status_code == status.HTTP_404_NOT_FOUND

    def test_add_duplicate_400(self, customer_user, db):
        category = MenuCategoryFactory(restaurant=RestaurantProfileFactory())
        item = MenuItemFactory(category=category)
        client = _client_for(customer_user)
        client.post(f"{WISHLIST}/add/", {"menu_item_id": item.id}, format="json")
        resp = client.post(f"{WISHLIST}/add/", {"menu_item_id": item.id}, format="json")
        assert resp.status_code == status.HTTP_400_BAD_REQUEST

    def test_anon_cannot_add(self, anon_api, db):
        resp = anon_api.post(f"{WISHLIST}/add/", {"menu_item_id": 1}, format="json")
        assert resp.status_code in (401, 403)


class TestWishlistRemove:
    def test_remove_item(self, customer_user, db):
        category = MenuCategoryFactory(restaurant=RestaurantProfileFactory())
        item = MenuItemFactory(category=category)
        wishlist = WishlistFactory(customer=customer_user.customer_profile)
        WishlistItemFactory(wishlist=wishlist, menu_item=item)
        resp = _client_for(customer_user).delete(f"{WISHLIST}/remove/{item.id}/")
        assert resp.status_code == status.HTTP_204_NO_CONTENT
        assert not WishlistItem.objects.filter(wishlist=wishlist).exists()

    def test_remove_item_not_in_wishlist_404(self, customer_user, db):
        WishlistFactory(customer=customer_user.customer_profile)
        resp = _client_for(customer_user).delete(f"{WISHLIST}/remove/999999/")
        assert resp.status_code == status.HTTP_404_NOT_FOUND

    def test_remove_without_wishlist_404(self, customer_user, db):
        resp = _client_for(customer_user).delete(f"{WISHLIST}/remove/1/")
        assert resp.status_code == status.HTTP_404_NOT_FOUND

    def test_cannot_remove_other_customers_item(self, customer_user, db):
        category = MenuCategoryFactory(restaurant=RestaurantProfileFactory())
        item = MenuItemFactory(category=category)
        WishlistItemFactory(wishlist__customer=CustomerProfileFactory(), menu_item=item)
        resp = _client_for(customer_user).delete(f"{WISHLIST}/remove/{item.id}/")
        assert resp.status_code == status.HTTP_404_NOT_FOUND
        assert WishlistItem.objects.filter(menu_item=item).exists()


class TestWishlistModel:
    def test_one_wishlist_per_customer(self):
        import pytest
        from django.db import IntegrityError

        wishlist = WishlistFactory()
        with pytest.raises(IntegrityError):
            WishlistFactory(customer=wishlist.customer)

    def test_unique_item_in_wishlist(self):
        import pytest
        from django.db import IntegrityError

        item = WishlistItemFactory()
        with pytest.raises(IntegrityError):
            WishlistItemFactory(wishlist=item.wishlist, menu_item=item.menu_item)
