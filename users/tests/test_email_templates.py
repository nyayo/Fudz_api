import pytest
from django.test import override_settings

from users.email_templates import EmailTemplates, get_email_template


TEMPLATE_CASES = [
    ("email_verification", {"user_name": "Ari", "verification_code": "123456"}),
    ("resend_verification", {"user_name": "Ari", "verification_code": "654321"}),
    ("password_reset", {"user_name": "Ari", "reset_code": "234567"}),
    ("password_reset_success", {"user_name": "Ari"}),
    ("welcome_verified", {"user_name": "Ari", "username": "ari"}),
    (
        "order_confirmation",
        {
            "user_name": "Ari",
            "order_id": "42",
            "items": [{"name": "Veggie bowl", "quantity": 1, "price": "$12"}],
            "subtotal": "$12",
            "delivery_fee": "$2",
            "total": "$14",
            "delivery_address": "12 Food Street",
        },
    ),
    (
        "order_status_update",
        {
            "user_name": "Ari",
            "order_id": "42",
            "status": "on_the_way",
            "status_message": "Your courier is nearby",
            "estimated_time": "5 minutes",
        },
    ),
    (
        "order_delivered",
        {"user_name": "Ari", "order_id": "42", "restaurant_name": "Cafe North", "items": []},
    ),
    (
        "promotion_discount",
        {
            "user_name": "Ari",
            "discount_amount": "20%",
            "description": "A fresh offer for dinner.",
            "expiry_date": "Friday",
            "food_items": [{"name": "Falafel bowl", "price": "$9"}],
            "restaurants": [{"name": "Cafe North", "cuisines": "Middle Eastern"}],
        },
    ),
    ("welcome_promo", {"user_name": "Ari", "promo_code": "WELCOME20", "discount_amount": "20%"}),
    (
        "delivery_driver_assigned",
        {"user_name": "Ari", "order_id": "42", "driver_name": "Lee", "estimated_time": "10 minutes"},
    ),
    ("delivery_arriving_soon", {"user_name": "Ari", "order_id": "42", "minutes_away": 5}),
    ("account_deactivated", {"user_name": "Ari"}),
    (
        "restaurant_invitation",
        {
            "user_name": "Ari",
            "restaurant_name": "Cafe North",
            "activation_url": "https://workspace.example/activate?token=one-time",
        },
    ),
]


@pytest.mark.parametrize(("template_type", "kwargs"), TEMPLATE_CASES)
@override_settings(COMPANY_NAME="Fudgo", CUSTOMER_APP_URL="https://customer.example")
def test_templates_use_the_shared_responsive_shell(template_type, kwargs):
    result = get_email_template(template_type, **kwargs)

    assert result["subject"]
    assert result["plain"]
    assert "<!doctype html>" in result["html"].lower()
    assert "max-width:600px" in result["html"]
    assert "prefers-reduced-motion: reduce" in result["html"]
    assert "email-motion-icon" in result["html"]
    assert 'href="#"' not in result["html"]
    assert "background-color: #FFF7F0" in result["html"]


@override_settings(COMPANY_NAME="Fudgo", CUSTOMER_APP_URL="https://customer.example")
def test_promotion_email_escapes_content_and_rejects_unsafe_links():
    result = EmailTemplates.promotion_discount(
        user_name='<script>alert("name")</script>',
        discount_amount="20%",
        description="A <script>alert('offer')</script> discount",
        expiry_date="Friday",
        hero_title="<script>title()</script>",
        hero_image_url="javascript:alert(1)",
        cta_link="javascript:alert(2)",
        food_items=[
            {
                "name": '<img src=x onerror="alert(1)">',
                "price": "$9",
                "image_url": "javascript:alert(3)",
            }
        ],
        restaurants=[{"name": "Cafe North", "link": "javascript:alert(4)"}],
    )

    html = result["html"]
    assert "<script>" not in html
    assert "javascript:" not in html
    assert "&lt;script&gt;" in html
    assert 'href="https://customer.example"' in html


@override_settings(
    COMPANY_NAME="Fudgo",
    CUSTOMER_APP_URL="https://customer.example",
    FRONTEND_URL="https://workspace.example",
)
def test_order_email_links_to_customer_app_and_status_colors_remain_semantic():
    order = get_email_template(
        "order_confirmation",
        user_name="Ari",
        order_id="42",
        items=[],
        subtotal="$12",
        delivery_fee="$2",
        total="$14",
        delivery_address="12 Food Street",
    )
    status = get_email_template(
        "order_status_update",
        user_name="Ari",
        order_id="42",
        status="on_the_way",
        status_message="Your courier is nearby",
    )

    assert 'href="https://customer.example"' in order["html"]
    assert "https://workspace.example" not in order["html"]
    assert 'class="email-step-active"' in status["html"]
    assert "#22c55e" in status["html"]
    assert "#8b5cf6" in status["html"]
    assert "background-color: #FF6B00 !important" in status["html"]
    assert "color: #24170D !important" in status["html"]
