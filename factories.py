"""
Shared factory_boy factories for the Fudz test suite.

All factories are Faker-backed and keyed to the real models in this repo:
users.User / profiles, restaurants.{Promotion, MenuCategory, MenuItem, images},
orders.{Cart, CartItem, Order, OrderItem}, delivery.*, reviews, wishlist.
"""
import factory
from datetime import timedelta
from django.contrib.gis.geos import Point
from django.utils import timezone
from faker import Faker

fake = Faker()


# Uganda-centric data helpers -------------------------------------------------
UG_KAMPALA = Point(32.5825, 0.3476, srid=4326)  # lng, lat
UG_ENTEBBE = Point(32.2905, 0.0512, srid=4326)


def ug_phone():
    """Ugandan mobile number in international format, e.g. +256772123456."""
    return f"+2567{fake.random_element(['7', '0', '8'])}{fake.numerify('#'*7)}"


class UserFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = "users.User"

    first_name = factory.Faker("first_name")
    last_name = factory.Faker("last_name")
    email = factory.LazyAttribute(lambda o: f"{fake.user_name()}.{fake.unique.random_int()}@test.fudz.ug")
    phone = factory.LazyFunction(ug_phone)
    user_type = "customer"
    password = factory.PostGenerationMethodCall("set_password", "TestPass123!")
    is_verified = True

    @factory.post_generation
    def finalize_username(self, create, extracted, **kwargs):
        # model.save() auto-generates a unique username from email/phone.
        pass


class SuperUserFactory(UserFactory):
    class Meta:
        model = "users.User"

    user_type = "customer"
    is_staff = True
    is_superuser = True
    is_verified = True
    email = factory.LazyAttribute(lambda o: f"admin.{fake.unique.random_int()}@test.fudz.ug")

    @classmethod
    def _create(cls, model_class, *args, **kwargs):
        manager = model_class.objects
        return manager.create_superuser(
            email=kwargs["email"],
            first_name=kwargs["first_name"],
            last_name=kwargs["last_name"],
            password="TestPass123!",
            phone=kwargs.get("phone"),
        )


class CustomerProfileFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = "users.CustomerProfile"

    user = factory.SubFactory(UserFactory, user_type="customer")
    current_location = factory.LazyFunction(lambda: UG_KAMPALA)
    order_stats = factory.LazyFunction(dict)


class RestaurantProfileFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = "users.RestaurantProfile"

    user = factory.SubFactory(UserFactory, user_type="restaurant")
    restaurant_name = factory.Faker("company")
    business_license = factory.LazyAttribute(
        lambda o: f"BL-{fake.unique.random_int(min=100000, max=999999)}"
    )
    address = factory.Faker("address")
    location = factory.LazyFunction(lambda: UG_KAMPALA)
    opening_hours = factory.LazyFunction(dict)
    rating = 0
    is_approved = True
    is_active = True


class CourierProfileFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = "users.CourierProfile"

    user = factory.SubFactory(UserFactory, user_type="courier")
    vehicle_type = factory.Faker("random_element", elements=("bike", "motorcycle", "car"))
    license_number = factory.LazyAttribute(lambda o: f"LIC-{fake.unique.random_int()}")
    is_available = True
    is_approved = True
    current_location = factory.LazyFunction(lambda: UG_KAMPALA)
    performance_stats = factory.LazyFunction(dict)
    rating = 0
    total_deliveries = 0
    earnings_balance = 0


class RestaurantStaffProfileFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = "users.RestaurantStaffProfile"

    user = factory.SubFactory(UserFactory, user_type="restaurant_staff")
    restaurant = factory.SubFactory(RestaurantProfileFactory)
    role = factory.Faker("random_element", elements=("manager", "waiter", "cashier"))
    is_active = True


class AddressFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = "users.Address"

    user = factory.SubFactory(UserFactory)
    label = "Home"
    street = factory.Faker("street_address")
    city = "Kampala"
    phone = factory.LazyFunction(ug_phone)
    location = factory.LazyFunction(lambda: UG_KAMPALA)


class NotificationPreferenceFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = "users.NotificationPreference"

    user = factory.SubFactory(UserFactory)


# restaurants -----------------------------------------------------------------
class PromotionFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = "restaurants.Promotion"

    restaurant = factory.SubFactory(RestaurantProfileFactory)
    name = factory.Faker("catch_phrase")
    description = factory.Faker("sentence")
    discount = 10.0
    start_date = factory.LazyFunction(
        lambda: timezone.now() - timedelta(days=1)
    )
    end_date = factory.LazyFunction(
        lambda: timezone.now() + timedelta(days=7)
    )
    is_active = True


class MenuCategoryFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = "restaurants.MenuCategory"

    restaurant = factory.SubFactory(RestaurantProfileFactory)
    name = factory.Faker("word")
    description = factory.Faker("sentence")
    position = 0
    is_active = True


class MenuItemFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = "restaurants.MenuItem"

    # restaurant is derived from the category so they always match
    restaurant = factory.SelfAttribute("category.restaurant")
    category = factory.SubFactory(MenuCategoryFactory)
    title = factory.LazyFunction(lambda: fake.word().title() + " Special")
    description = factory.Faker("sentence")
    price = factory.Faker("pydecimal", left_digits=4, right_digits=2, positive=True, min_value=1)
    is_available = True
    is_featured = False
    prep_time_minutes = 15


class MenuItemImageFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = "restaurants.MenuItemImage"

    menu_item = factory.SubFactory(MenuItemFactory)
    image = factory.django.ImageField(color="green", width=16, height=16, format="PNG")
    alt_text = ""


# orders ----------------------------------------------------------------------
class CartFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = "orders.Cart"

    user = factory.SubFactory(UserFactory)


class CartItemFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = "orders.CartItem"

    cart = factory.SubFactory(CartFactory)
    menu_item = factory.SubFactory(MenuItemFactory)
    qty = 1


class OrderFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = "orders.Order"

    customer = factory.SubFactory(CustomerProfileFactory)
    restaurant = factory.SubFactory(RestaurantProfileFactory)
    courier = None
    pickup_location = factory.LazyFunction(lambda: UG_KAMPALA)
    dropoff_location = factory.LazyFunction(lambda: UG_ENTEBBE)
    status = "placed"
    payment_status = "pending"
    total_price = 0
    delivery_fee = 0
    tax = 0


class OrderItemFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = "orders.OrderItem"

    order = factory.SubFactory(OrderFactory)
    menu_item = factory.SubFactory(MenuItemFactory)
    qty = 1
    unit_price = factory.LazyAttribute(lambda o: o.menu_item.price)
    discount_amount = 0


# delivery --------------------------------------------------------------------
class DeliveryRequestFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = "delivery.DeliveryRequest"

    order = factory.SubFactory(OrderFactory)
    courier = None
    status = "pending"
    pickup_location = factory.LazyFunction(lambda: UG_KAMPALA)
    dropoff_location = factory.LazyFunction(lambda: UG_ENTEBBE)


class DeliveryTrackingFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = "delivery.DeliveryTracking"

    delivery = factory.SubFactory(DeliveryRequestFactory)
    courier = factory.SubFactory(CourierProfileFactory)
    current_location = factory.LazyFunction(lambda: UG_KAMPALA)


class CourierEarningsFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = "delivery.CourierEarnings"

    courier = factory.SubFactory(CourierProfileFactory)
    order = factory.SubFactory(OrderFactory)
    amount = 5000
    commission_rate = 10


# reviews / wishlist ----------------------------------------------------------
class RestaurantReviewFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = "reviews.RestaurantReview"

    customer = factory.SubFactory(CustomerProfileFactory)
    restaurant = factory.SubFactory(RestaurantProfileFactory)
    rating = 5
    comment = factory.Faker("sentence")


class WishlistFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = "wishlist.Wishlist"

    customer = factory.SubFactory(CustomerProfileFactory)


class WishlistItemFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = "wishlist.WishlistItem"

    wishlist = factory.SubFactory(WishlistFactory)
    menu_item = factory.SubFactory(MenuItemFactory)
