"""reviews API tests: create, ownership rules, duplicate prevention."""
import pytest
from rest_framework import status
from rest_framework.test import APIClient

from factories import (
    CustomerProfileFactory,
    RestaurantProfileFactory,
    RestaurantReviewFactory,
)
from reviews.models import RestaurantReview

pytestmark = [pytest.mark.django_db, pytest.mark.views]

REVIEWS = "/api/v1/reviews"


def _client_for(user):
    client = APIClient()
    client.force_authenticate(user)
    return client


class TestReviewList:
    def test_requires_auth(self, anon_api):
        assert anon_api.get(f"{REVIEWS}/").status_code in (401, 403)

    def test_filter_by_restaurant(self, customer_user, db):
        r1 = RestaurantProfileFactory()
        mine = RestaurantReviewFactory(restaurant=r1, customer=customer_user.customer_profile)
        RestaurantReviewFactory()
        resp = _client_for(customer_user).get(f"{REVIEWS}/", {"restaurant": r1.id})
        rows = resp.data["results"] if isinstance(resp.data, dict) else resp.data
        assert [r["id"] for r in rows] == [mine.id]


class TestReviewCreate:
    def test_customer_creates_review(self, customer_user, db):
        from django.contrib.auth.models import Permission

        customer_user.user_permissions.add(
            Permission.objects.get(codename="add_restaurantreview")
        )
        restaurant = RestaurantProfileFactory()
        resp = _client_for(customer_user).post(
            f"{REVIEWS}/",
            {"restaurant": restaurant.id, "rating": 5, "comment": "Great rolex"},
            format="json",
        )
        assert resp.status_code == status.HTTP_201_CREATED, resp.data
        assert RestaurantReview.objects.filter(customer=customer_user.customer_profile).exists()

    def test_rating_out_of_range_400(self, customer_user, db):
        from django.contrib.auth.models import Permission

        customer_user.user_permissions.add(
            Permission.objects.get(codename="add_restaurantreview")
        )
        restaurant = RestaurantProfileFactory()
        resp = _client_for(customer_user).post(
            f"{REVIEWS}/",
            {"restaurant": restaurant.id, "rating": 9},
            format="json",
        )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST

    def test_anon_cannot_create(self, anon_api, db):
        restaurant = RestaurantProfileFactory()
        resp = anon_api.post(
            f"{REVIEWS}/", {"restaurant": restaurant.id, "rating": 5}, format="json"
        )
        assert resp.status_code in (401, 403)


class TestReviewOwnership:
    def test_owner_can_update(self, customer_user, db):
        from django.contrib.auth.models import Permission

        customer_user.user_permissions.add(
            Permission.objects.get(codename="change_restaurantreview")
        )
        review = RestaurantReviewFactory(customer=customer_user.customer_profile)
        resp = _client_for(customer_user).patch(
            f"{REVIEWS}/{review.id}/", {"rating": 2}, format="json"
        )
        assert resp.status_code == 200
        review.refresh_from_db()
        assert review.rating == 2

    def test_non_owner_cannot_update(self, customer_user, db):
        review = RestaurantReviewFactory()
        resp = _client_for(customer_user).patch(
            f"{REVIEWS}/{review.id}/", {"rating": 1}, format="json"
        )
        assert resp.status_code in (403, 404)

    def test_owner_can_delete(self, customer_user, db):
        from django.contrib.auth.models import Permission

        customer_user.user_permissions.add(
            Permission.objects.get(codename="delete_restaurantreview")
        )
        review = RestaurantReviewFactory(customer=customer_user.customer_profile)
        resp = _client_for(customer_user).delete(f"{REVIEWS}/{review.id}/")
        assert resp.status_code == status.HTTP_204_NO_CONTENT

    def test_staff_can_delete_any(self, admin_user, db):
        review = RestaurantReviewFactory()
        resp = _client_for(admin_user).delete(f"{REVIEWS}/{review.id}/")
        assert resp.status_code == status.HTTP_204_NO_CONTENT


class TestReviewModelConstraints:
    def test_unique_customer_restaurant_pair(self):
        import pytest
        from django.db import IntegrityError

        review = RestaurantReviewFactory()
        with pytest.raises(IntegrityError):
            RestaurantReviewFactory(
                customer=review.customer, restaurant=review.restaurant
            )

    def test_rating_bounds(self):
        from django.core.exceptions import ValidationError

        review = RestaurantReviewFactory.build(rating=6)
        with pytest.raises(ValidationError):
            review.full_clean()
