"""restaurants model tests: promotions, categories, menu items, constraints."""
import pytest
from datetime import timedelta
from decimal import Decimal
from django.core.exceptions import ValidationError
from django.db import IntegrityError
from django.utils import timezone

from factories import (
    MenuCategoryFactory,
    MenuItemFactory,
    PromotionFactory,
    RestaurantProfileFactory,
)
from restaurants.models import Promotion

pytestmark = [pytest.mark.django_db, pytest.mark.models]


class TestPromotion:
    def test_discount_non_negative(self):
        # MinValueValidator runs on full_clean; factory save() bypasses it
        promo = PromotionFactory.build(discount=-5.0)
        with pytest.raises(ValidationError):
            promo.full_clean()

    def test_promotion_ordering_by_created(self):
        # created_at resolution is too coarse for two rapid inserts; pin ids
        from django.utils import timezone
        from datetime import timedelta

        p1 = PromotionFactory()
        p2 = PromotionFactory()
        Promotion.objects.filter(pk=p1.pk).update(
            created_at=timezone.now() - timedelta(hours=1)
        )
        assert list(Promotion.objects.all()) == [p2, p1]

    def test_active_window_filter(self):
        active = PromotionFactory(
            start_date=timezone.now() - timedelta(hours=1),
            end_date=timezone.now() + timedelta(hours=1),
        )
        expired = PromotionFactory(
            start_date=timezone.now() - timedelta(days=2),
            end_date=timezone.now() - timedelta(days=1),
        )
        now = timezone.now()
        qs = Promotion.objects.filter(is_active=True, start_date__lte=now, end_date__gte=now)
        assert active in qs and expired not in qs


class TestMenuCategory:
    def test_unique_name_per_restaurant(self):
        restaurant = RestaurantProfileFactory()
        MenuCategoryFactory(restaurant=restaurant, name="Mains")
        with pytest.raises(IntegrityError):
            MenuCategoryFactory(restaurant=restaurant, name="Mains")

    def test_same_name_different_restaurants_ok(self):
        MenuCategoryFactory(name="Drinks")
        MenuCategoryFactory(name="Drinks")
        from restaurants.models import MenuCategory

        assert MenuCategory.objects.count() == 2


class TestMenuItem:
    def test_category_must_belong_to_same_restaurant(self):
        restaurant = RestaurantProfileFactory()
        other_category = MenuCategoryFactory()  # different restaurant
        item = MenuItemFactory.build(restaurant=restaurant, category=other_category)
        with pytest.raises(ValidationError):
            item.save()  # save() calls full_clean()

    def test_price_minimum(self):
        restaurant = RestaurantProfileFactory()
        category = MenuCategoryFactory(restaurant=restaurant)
        item = MenuItemFactory.build(
            restaurant=restaurant, category=category, price=Decimal("0.00")
        )
        with pytest.raises(ValidationError):
            item.save()

    def test_unique_title_per_restaurant(self):
        restaurant = RestaurantProfileFactory()
        category = MenuCategoryFactory(restaurant=restaurant)
        MenuItemFactory(restaurant=restaurant, category=category, title="Rolex")
        # MenuItem.save() runs full_clean(), so the uniqueness constraint
        # surfaces as ValidationError, not IntegrityError
        with pytest.raises(ValidationError):
            MenuItemFactory(restaurant=restaurant, category=category, title="Rolex")

    def test_get_offer_price_with_active_promotion(self):
        item = MenuItemFactory(price=Decimal("10000.00"))
        promo = PromotionFactory(
            restaurant=item.restaurant, discount=30.0,
            start_date=timezone.now() - timedelta(hours=1),
            end_date=timezone.now() + timedelta(hours=1),
        )
        item.promotions.add(promo)
        assert item.get_offer_price() == Decimal("7000.00")

    def test_get_offer_price_no_promotion(self):
        item = MenuItemFactory(price=Decimal("10000.00"))
        assert item.get_offer_price() == item.price

    def test_get_effective_price_returns_promotion(self):
        item = MenuItemFactory(price=Decimal("10000.00"))
        promo = PromotionFactory(
            restaurant=item.restaurant, discount=10.0,
            start_date=timezone.now() - timedelta(hours=1),
            end_date=timezone.now() + timedelta(hours=1),
        )
        item.promotions.add(promo)
        price, applied = item.get_effective_price()
        assert price == Decimal("9000.00")
        assert applied == promo

    def test_best_promotion_wins(self):
        item = MenuItemFactory(price=Decimal("10000.00"))
        now = timezone.now()
        small = PromotionFactory(restaurant=item.restaurant, discount=10.0, start_date=now - timedelta(hours=1), end_date=now + timedelta(hours=1))
        big = PromotionFactory(restaurant=item.restaurant, discount=25.0, start_date=now - timedelta(hours=1), end_date=now + timedelta(hours=1))
        item.promotions.add(small, big)
        assert item.get_active_promotion() == big
