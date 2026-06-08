# users/email_templates.py
"""
Modern Email Templates for Fudgo Food Delivery
Glovo-style design with green color palette, dark mode support, and table-based layout
"""

from typing import Any, Dict
from django.conf import settings


class EmailTemplates:
    """Professional email templates with dark mode support and green theme"""

    # ============================================================
    # BASE STYLES - Shared CSS for all templates
    # ============================================================
    
    BASE_STYLES = """
    :root {
      color-scheme: light dark;
      supported-color-schemes: light dark;
    }
    .main {
      padding: 0;
      margin: 0;
      font-family: Verdana, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif !important;
      font-size: 16px;
      letter-spacing: 0;
      line-height: 1.4;
      background-color: #f9fafb;
    }
    table {
      width: 100%;
    }
    td {
      font-family: Verdana, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif !important;
    }
    td a {
      color: #22c55e;
      text-decoration: none;
    }
    a.no-color {
      color: inherit;
    }
    .header {
      background-color: #f0fdf4;
      border-radius: 0 0 80px 0;
      max-width: 1200px;
    }
    .header__title {
      font-size: 1.75em;
      font-weight: bold;
      padding: 24px 0;
      letter-spacing: -0.5px;
      color: #1f2937;
    }
    .header__subtitle {
      color: #6b7280;
      padding-bottom: 24px;
    }
    .header__inner-container {
      padding: 40px 24px 60px;
      margin: 0;
    }
    .body__details {
      padding: 12px;
    }
    .body__background {
      background-color: #f3f4f6;
    }
    .highlight {
      color: #166534;
      background-color: #dcfce7;
      border: none;
      padding: 3px 8px;
      border-radius: 5px;
      font-size: 0.75em;
      font-weight: 500;
    }
    .table__padded td {
      padding: 12px;
    }
    .table__padded td td {
      padding: 0;
    }
    .indent {
      background-color: white;
    }
    .label {
      color: inherit !important;
      text-decoration: none !important;
    }
    .label-details {
      color: #6b7280 !important;
      text-decoration: none !important;
    }
    .product__promotion {
      background-color: #22c55e;
      color: white;
      font-size: 0.7em;
      padding: 2px 6px;
      border-radius: 4px;
    }
    .btn-primary {
      color: white !important;
      background-color: #22c55e;
      padding: 12px 24px;
      font-size: 0.875em;
      border-radius: 8px;
      font-weight: bold;
      text-decoration: none;
      display: inline-block;
    }
    .btn-primary:hover {
      background-color: #16a34a;
    }
    .footer {
      padding: 32px 24px;
      text-align: center;
      background-color: #1f2937;
    }
    .footer p {
      color: #9ca3af;
      font-size: 12px;
      margin: 4px 0;
    }
    .footer a {
      color: #22c55e;
    }
    /* Dark Mode Support */
    @media (prefers-color-scheme: dark) {
      .main {
        color: #f9fafb !important;
        background-color: #111827 !important;
      }
      .header {
        background-color: #14532d !important;
        color: white !important;
      }
      .header__title {
        color: white !important;
      }
      .header__subtitle {
        color: #d1d5db !important;
      }
      .body__background {
        background-color: #1f2937 !important;
        color: white !important;
      }
      .indent {
        background-color: #111827 !important;
      }
      .highlight {
        background-color: #064e3b !important;
        color: #86efac !important;
      }
      .label {
        color: inherit !important;
      }
      .label-details {
        color: #9ca3af !important;
      }
      .footer {
        background-color: #0f172a !important;
      }
    }
    /* Mobile Responsive */
    @media (max-width: 600px) {
      .header__inner-container {
        padding: 32px 16px 48px;
      }
      .header__title {
        font-size: 1.5em;
      }
      .body__details {
        padding: 8px;
      }
    }
    """

    @staticmethod
    def _get_year() -> int:
        from datetime import datetime
        return datetime.now().year

    @staticmethod
    def _get_company_name() -> str:
        return getattr(settings, "COMPANY_NAME", "Fudgo")
    
    @classmethod
    def _base_template(cls, content: str, preheader: str = "") -> str:
        """Wrap content in base email structure with dark mode support"""
        return f"""<!doctype html>
<html lang="en">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
  <meta name="viewport" content="width=device-width, user-scalable=no, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0">
  <meta http-equiv="X-UA-Compatible" content="ie=edge">
  <meta name="color-scheme" content="light dark">
  <meta name="supported-color-schemes" content="light dark only">
  <title>Fudgo</title>
  <style type="text/css">
    {cls.BASE_STYLES}
  </style>
</head>
<body class="main">
<div style="color:transparent;visibility:hidden;opacity:0;font-size:0px;border:0;max-height:1px;width:1px;margin:0px;padding:0px;display:none!important;line-height:0px!important;">{preheader}</div>
{content}
</body>
</html>"""
    
    @classmethod
    def _header(cls, title: str, subtitle: str = "", icon: str = "🍔") -> str:
        """Generate styled header section"""
        subtitle_html = f'<tr><td class="header__subtitle">{subtitle}</td></tr>' if subtitle else ""
        return f"""
  <table style="max-width:100%;" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr><td align="center">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:600px">
        <tr><td class="header">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
            <tr><td align="center">
              <table style="max-width: 560px" class="header__inner-container" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td style="font-size: 32px;">{icon} <strong style="color: #22c55e; font-size: 24px;">Fudgo</strong></td>
                </tr>
                <tr><td class="header__title"><a class="no-color" rel="nofollow">{title}</a></td></tr>
                {subtitle_html}
              </table>
            </td></tr>
          </table>
        </td></tr>
      </table>
    </td></tr>
    <tr><td style="height: 24px;"></td></tr>
  </table>"""

    @classmethod
    def _footer(cls, message: str = "") -> str:
        """Generate styled footer section"""
        msg_html = f'<p style="color: #d1d5db; margin-bottom: 12px;">{message}</p>' if message else ""
        return f"""
  <table style="max-width:600px; margin: 0 auto;" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr><td class="footer">
      {msg_html}
      <p style="font-size: 20px; margin-bottom: 8px;">🍔 <span style="color: #22c55e; font-weight: bold;">Fudgo</span></p>
      <p>© {cls._get_year()} Fudgo. All rights reserved.</p>
      <p style="margin-top: 8px;"><a href="#">Unsubscribe</a> · <a href="#">Privacy Policy</a></p>
    </td></tr>
  </table>"""
    
    @classmethod
    def _dashed_separator(cls) -> str:
        """Generate dashed separator line"""
        return """
<table border="0" width="100%" cellpadding="0" cellspacing="0">
  <tr><td style="padding-top: 12px;height:0;font-size:0"></td></tr>
  <tr>
    <td style="width:12px;"></td>
    <td style="background:none; border-top: 2px dashed #d1d5db; font-size: 0">&nbsp;</td>
    <td style="width:12px;"></td>
  </tr>
  <tr><td style="padding-top: 12px;height:0;font-size:0"></td></tr>
</table>"""

    @classmethod
    def _code_box(cls, code: str, label: str = "Your Code") -> str:
        """Generate styled verification code box"""
        return f"""
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin: 24px 0;">
  <tr><td align="center">
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" style="background: #f0fdf4; border: 2px dashed #22c55e; border-radius: 12px; padding: 24px 40px;">
      <tr><td align="center">
        <p style="color: #16a34a; font-size: 11px; text-transform: uppercase; letter-spacing: 2px; margin: 0 0 12px; font-weight: 600;">{label}</p>
        <p style="font-size: 36px; font-weight: 800; color: #15803d; letter-spacing: 8px; font-family: 'Courier New', monospace; margin: 0;">{code}</p>
      </td></tr>
    </table>
  </td></tr>
</table>"""

    # ============================================================
    # VERIFICATION EMAIL - Clean, trustworthy, focus on the code
    # ============================================================
    @classmethod
    def email_verification(cls, user_name: str, verification_code: str) -> Dict[str, str]:
        """Email verification - minimal, code-focused design with dark mode"""
        
        header = cls._header(
            f"Hey {user_name}! 👋 Verify your email",
            "Enter this code to verify your email and start ordering delicious food.",
            "🔐"
        )
        
        code_box = cls._code_box(verification_code, "Verification Code")
        
        body = f"""
  <table style="max-width:600px; margin: 0 auto;" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr><td class="body__details body__background" style="border-radius: 16px; padding: 24px;">
      <table class="table__padded" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
        <tr><td align="center">
          {code_box}
          <table role="presentation" cellpadding="0" cellspacing="0" border="0" style="background: #fef3c7; border-radius: 8px; padding: 12px 20px; margin: 16px 0;">
            <tr><td>
              <p style="color: #92400e; font-size: 13px; margin: 0;">⏱️ This code expires in <strong>30 minutes</strong></p>
            </td></tr>
          </table>
          <p style="color: #6b7280; font-size: 13px; margin-top: 24px;">Didn't create an account? Just ignore this email.</p>
        </td></tr>
      </table>
    </td></tr>
  </table>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr><td style="height: 24px;"></td></tr>
  </table>"""
        
        footer = cls._footer()
        
        html = cls._base_template(
            header + body + footer,
            f"Your verification code is {verification_code}"
        )
        
        plain = f"""Hey {user_name}!

Welcome to Fudgo! Your verification code is: {verification_code}

This code expires in 30 minutes.

Didn't create an account? Just ignore this email.

© {cls._get_year()} Fudgo"""

        return {"subject": "🔐 Verify Your Email – Fudgo", "html": html, "plain": plain}

    # ============================================================
    # RESEND VERIFICATION - Simple refresh design
    # ============================================================
    @classmethod
    def resend_verification(cls, user_name: str, verification_code: str) -> Dict[str, str]:
        """Resend verification - refresh/retry themed with dark mode"""
        
        header = cls._header(
            f"New Verification Code 🔄",
            f"No worries, <strong>{user_name}</strong>! Here's a fresh new code for you.",
            "🔄"
        )
        
        code_box = cls._code_box(verification_code, "✨ Fresh Code")
        
        body = f"""
  <table style="max-width:600px; margin: 0 auto;" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr><td class="body__details body__background" style="border-radius: 16px; padding: 24px;">
      <table class="table__padded" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
        <tr><td align="center">
          {code_box}
          <p style="color: #6b7280; font-size: 13px; margin-top: 16px;">Valid for <strong style="color: #dc2626;">30 minutes</strong></p>
        </td></tr>
      </table>
    </td></tr>
  </table>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr><td style="height: 24px;"></td></tr>
  </table>"""
        
        footer = cls._footer()
        
        html = cls._base_template(
            header + body + footer,
            f"Your new verification code is {verification_code}"
        )
        
        plain = f"""New Verification Code for {user_name}

Your fresh code: {verification_code}

Valid for 30 minutes.

© {cls._get_year()} Fudgo"""

        return {"subject": "🔄 New Verification Code – Fudgo", "html": html, "plain": plain}

    # ============================================================
    # PASSWORD RESET - Security focused, serious but friendly
    # ============================================================
    @classmethod
    def password_reset(cls, user_name: str, reset_code: str) -> Dict[str, str]:
        """Password reset - security-themed with lock icon and dark mode"""
        
        header = cls._header(
            "Password Reset Request 🔐",
            f"Hi <strong>{user_name}</strong>, we received a reset request for your account.",
            "🔐"
        )
        
        code_box = cls._code_box(reset_code, "Reset Code")
        
        body = f"""
  <table style="max-width:600px; margin: 0 auto;" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr><td class="body__details body__background" style="border-radius: 16px; padding: 24px;">
      <table class="table__padded" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
        <tr><td align="center">
          {code_box}
          <p style="color: #dc2626; font-size: 14px; font-weight: 600; margin: 16px 0;">⏱️ Expires in 15 minutes</p>
          <table role="presentation" cellpadding="0" cellspacing="0" border="0" style="background: #fef3c7; border-left: 4px solid #f59e0b; border-radius: 0 8px 8px 0; padding: 16px; margin: 24px 0; text-align: left;">
            <tr><td>
              <p style="color: #92400e; font-size: 13px; margin: 0; line-height: 1.5;">
                <strong>⚠️ Didn't request this?</strong><br>
                If you didn't request a password reset, ignore this email. Your password won't change.
              </p>
            </td></tr>
          </table>
        </td></tr>
      </table>
    </td></tr>
  </table>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr><td style="height: 24px;"></td></tr>
  </table>"""
        
        footer = cls._footer()
        
        html = cls._base_template(
            header + body + footer,
            f"Your password reset code is {reset_code}"
        )
        
        plain = f"""Password Reset Request

Hi {user_name},

Your reset code: {reset_code}

This code expires in 15 minutes.

If you didn't request this, ignore this email.

© {cls._get_year()} Fudgo Security Team"""

        return {"subject": "🔐 Password Reset Code – Fudgo", "html": html, "plain": plain}

    # ============================================================
    # PASSWORD RESET SUCCESS - Celebratory with checkmark
    # ============================================================
    @classmethod
    def password_reset_success(cls, user_name: str) -> Dict[str, str]:
        """Password reset success - confirmation with shield and dark mode"""
        
        header = cls._header(
            "Password Updated! ✅",
            f"Great news, <strong>{user_name}</strong>! Your password has been successfully changed.",
            "✅"
        )
        
        body = f"""
  <table style="max-width:600px; margin: 0 auto;" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr><td class="body__details body__background" style="border-radius: 16px; padding: 24px;">
      <table class="table__padded" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
        <tr><td align="center">
          <table role="presentation" cellpadding="0" cellspacing="0" border="0" style="background: #f0fdf4; border: 2px solid #22c55e; border-radius: 12px; padding: 20px 40px; margin: 16px 0;">
            <tr><td align="center">
              <p style="color: #166534; font-size: 16px; margin: 0;">🎉 You can now log in with your new password</p>
            </td></tr>
          </table>
          
          <table role="presentation" cellpadding="0" cellspacing="0" border="0" style="background: #f9fafb; border-radius: 12px; padding: 20px; margin: 24px 0; text-align: left; width: 100%;">
            <tr><td>
              <p style="color: #1f2937; font-size: 14px; font-weight: 600; margin: 0 0 12px;">🛡️ Security Tips</p>
              <p style="color: #4b5563; font-size: 13px; margin: 8px 0;">📱 Enable two-factor authentication</p>
              <p style="color: #4b5563; font-size: 13px; margin: 8px 0;">🔑 Use a unique password</p>
              <p style="color: #4b5563; font-size: 13px; margin: 8px 0;">👀 Check your recent activity</p>
            </td></tr>
          </table>
          
          <a href="#" class="btn-primary" style="margin-top: 16px;">Open Fudgo App</a>
        </td></tr>
      </table>
    </td></tr>
  </table>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr><td style="height: 24px;"></td></tr>
  </table>"""
        
        footer = cls._footer()
        
        html = cls._base_template(
            header + body + footer,
            "Your password has been successfully updated"
        )
        
        plain = f"""Password Successfully Updated!

Hi {user_name},

Your Fudgo password has been changed. You can now log in with your new password.

Security Tips:
• Enable two-factor authentication
• Use a unique password
• Check your recent activity

© {cls._get_year()} Fudgo"""

        return {"subject": "✅ Password Updated – Fudgo", "html": html, "plain": plain}

    # ============================================================
    # WELCOME VERIFIED - Celebratory, exciting, colorful
    # ============================================================
    @classmethod
    def welcome_verified(cls, user_name: str, username: str) -> Dict[str, str]:
        """Welcome email - party/celebration theme with dark mode"""
        
        header = cls._header(
            f"Welcome to Fudgo! 🎉",
            "Your email is verified – let's eat!",
            "🎉"
        )
        
        body = f"""
  <table style="max-width:600px; margin: 0 auto;" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr><td class="body__details body__background" style="border-radius: 16px; padding: 24px;">
      <table class="table__padded" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
        <tr><td align="center">
          <!-- User Card -->
          <table role="presentation" cellpadding="0" cellspacing="0" border="0" style="background: linear-gradient(135deg, #f0fdf4 0%, #ecfdf5 100%); border-radius: 12px; padding: 24px; text-align: center; margin-bottom: 24px; border: 2px solid #22c55e; width: 100%;">
            <tr><td align="center">
              <div style="width: 64px; height: 64px; background: #22c55e; border-radius: 50%; display: inline-block; line-height: 64px; font-size: 28px; color: #fff; font-weight: 700;">{user_name[0].upper()}</div>
              <p style="color: #16a34a; font-size: 18px; font-weight: 700; margin: 12px 0 4px;">@{username}</p>
              <p style="color: #6b7280; font-size: 13px; margin: 0;">✓ Verified Account</p>
            </td></tr>
          </table>
          
          <!-- Features -->
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin: 24px 0;">
            <tr><td style="background: #f9fafb; border-radius: 8px; padding: 16px; margin-bottom: 8px;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td style="width: 48px; font-size: 28px; vertical-align: top;">🍕</td>
                  <td>
                    <p style="color: #1f2937; font-size: 15px; margin: 0; font-weight: 600;">Thousands of Restaurants</p>
                    <p style="color: #6b7280; font-size: 13px; margin: 4px 0 0;">From local gems to your favorites</p>
                  </td>
                </tr>
              </table>
            </td></tr>
            <tr><td style="height: 8px;"></td></tr>
            <tr><td style="background: #f9fafb; border-radius: 8px; padding: 16px;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td style="width: 48px; font-size: 28px; vertical-align: top;">⚡</td>
                  <td>
                    <p style="color: #1f2937; font-size: 15px; margin: 0; font-weight: 600;">Lightning Fast Delivery</p>
                    <p style="color: #6b7280; font-size: 13px; margin: 4px 0 0;">Hot food at your door, quick</p>
                  </td>
                </tr>
              </table>
            </td></tr>
            <tr><td style="height: 8px;"></td></tr>
            <tr><td style="background: #f9fafb; border-radius: 8px; padding: 16px;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td style="width: 48px; font-size: 28px; vertical-align: top;">🎁</td>
                  <td>
                    <p style="color: #1f2937; font-size: 15px; margin: 0; font-weight: 600;">Exclusive Deals</p>
                    <p style="color: #6b7280; font-size: 13px; margin: 4px 0 0;">Members-only discounts daily</p>
                  </td>
                </tr>
              </table>
            </td></tr>
            <tr><td style="height: 8px;"></td></tr>
            <tr><td style="background: #f9fafb; border-radius: 8px; padding: 16px;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td style="width: 48px; font-size: 28px; vertical-align: top;">📍</td>
                  <td>
                    <p style="color: #1f2937; font-size: 15px; margin: 0; font-weight: 600;">Real-time Tracking</p>
                    <p style="color: #6b7280; font-size: 13px; margin: 4px 0 0;">Watch your food come to you</p>
                  </td>
                </tr>
              </table>
            </td></tr>
          </table>
          
          <a href="#" class="btn-primary" style="margin-top: 16px; padding: 16px 40px; font-size: 16px;">Start Ordering Now 🚀</a>
        </td></tr>
      </table>
    </td></tr>
  </table>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr><td style="height: 24px;"></td></tr>
  </table>"""
        
        footer = cls._footer(f"Made with 💚 for food lovers")
        
        html = cls._base_template(
            header + body + footer,
            f"Welcome to Fudgo, {user_name}! Your email is verified."
        )
        
        plain = f"""🎉 Welcome to Fudgo, {user_name}!

Your email is verified! Username: @{username}

What you can do now:
🍕 Browse thousands of restaurants
⚡ Get lightning fast delivery
🎁 Access exclusive deals
📍 Track your orders in real-time

Start ordering at fudgo.com

© {cls._get_year()} Fudgo"""

        return {"subject": f"🎉 Welcome to Fudgo, {user_name}!", "html": html, "plain": plain}

    # ============================================================
    # ORDER CONFIRMATION - Receipt style, clean, professional
    # ============================================================
    @classmethod
    def order_confirmation(
        cls, user_name: str, order_id: str, items: list,
        subtotal: str, delivery_fee: str, total: str,
        delivery_address: str, estimated_time: str = "30-45 mins",
        restaurant_name: str = ""
    ) -> Dict[str, str]:
        """Order confirmation - receipt/invoice style with product images and dark mode"""
        
        # Build items HTML
        items_html = ""
        items_text = ""
        for item in items:
            image_url = item.get('image_url', '')
            name = item.get('name', '')
            qty = item.get('quantity', 1)
            price = item.get('price', '')
            original_price = item.get('original_price', '')
            
            image_cell = f'<img src="{image_url}" alt="{name}" style="width: 60px; height: 60px; border-radius: 8px; object-fit: cover;">' if image_url else '<div style="width: 60px; height: 60px; border-radius: 8px; background: #f0fdf4; text-align: center; line-height: 60px; font-size: 24px;">🍽️</div>'
            
            original_price_html = f'<tr><td align="right" style="text-decoration: line-through; color: #9ca3af; font-size: 0.875em; padding-top: 3px;">{original_price}</td></tr>' if original_price and original_price != price else ""
            
            items_html += f"""
        <tr style="vertical-align: top">
          <td style="padding: 12px 0; width: 30px;"><strong>{qty}x</strong></td>
          <td style="padding: 12px 0;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
              <tr>
                <td style="width: 72px; vertical-align: top;">{image_cell}</td>
                <td style="padding-left: 12px; vertical-align: top;">
                  <p style="margin: 0; font-weight: 600; color: #1f2937;">{name}</p>
                </td>
              </tr>
            </table>
          </td>
          <td align="right" style="padding: 12px 0; white-space: nowrap; vertical-align: top;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
              <tr><td align="right" style="font-weight: 600;">{price}</td></tr>
              {original_price_html}
            </table>
          </td>
        </tr>"""
            items_text += f"  {name} × {qty} - {price}\n"
        
        restaurant_html = f'<p style="color: #6b7280; font-size: 14px; margin-top: 8px;">🏪 From <strong>{restaurant_name}</strong></p>' if restaurant_name else ""
        
        header = cls._header(
            f"Order Confirmed! ✓",
            f"Order #{order_id}{restaurant_html}",
            "✓"
        )
        
        separator = cls._dashed_separator()
        
        body = f"""
  <table style="max-width:600px; margin: 0 auto;" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr><td class="body__details body__background" style="border-radius: 16px 16px 0 0; padding: 16px;">
      <!-- ETA Box -->
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background: linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%); border-radius: 12px; padding: 20px; margin-bottom: 16px;">
        <tr><td align="center">
          <p style="color: #166534; font-size: 12px; text-transform: uppercase; letter-spacing: 1px; margin: 0;">Estimated Delivery</p>
          <p style="color: #15803d; font-size: 28px; font-weight: 800; margin: 8px 0 0;">🕐 {estimated_time}</p>
        </td></tr>
      </table>
      
      <!-- Products Header -->
      <table class="table__padded" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
        <tr>
          <td><strong>Products</strong></td>
          <td align="right" style="white-space: nowrap; vertical-align: top">
            <span class="highlight">Order #{order_id}</span>
          </td>
        </tr>
      </table>
      
      <!-- Items List -->
      <table class="table__padded" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
        {items_html}
      </table>
      
      {separator}
      
      <!-- Totals -->
      <table class="table__padded" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
        <tr>
          <td style="padding: 8px 12px; color: #6b7280;">Subtotal</td>
          <td align="right" style="padding: 8px 12px; color: #6b7280;">{subtotal}</td>
        </tr>
        <tr>
          <td style="padding: 8px 12px; color: #6b7280;">Delivery Fee</td>
          <td align="right" style="padding: 8px 12px; color: #6b7280;">{delivery_fee}</td>
        </tr>
      </table>
    </td></tr>
  </table>
  
  <!-- Total Row -->
  <table style="max-width:600px; margin: 0 auto;" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr><td class="body__details body__background" style="border-radius: 0 0 16px 16px; padding: 0 16px 16px;">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background: #f0fdf4; border-radius: 8px;">
        <tr>
          <td style="padding: 16px; font-size: 18px; font-weight: 700; color: #1f2937;">Total</td>
          <td align="right" style="padding: 16px; font-size: 18px; font-weight: 700; color: #22c55e;">{total}</td>
        </tr>
      </table>
    </td></tr>
  </table>
  
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr><td style="height: 16px;"></td></tr>
  </table>
  
  <!-- Delivery Address -->
  <table style="max-width:600px; margin: 0 auto;" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr><td class="body__details body__background" style="border-radius: 16px; padding: 16px;">
      <p style="font-weight: 600; margin: 0 0 8px; color: #1f2937;">📍 Delivery Address</p>
      <p style="color: #6b7280; margin: 0; line-height: 1.5;">{delivery_address}</p>
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-top: 16px;">
        <tr><td align="center">
          <a href="#" class="btn-primary">Track Your Order 📍</a>
        </td></tr>
      </table>
    </td></tr>
  </table>
  
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr><td style="height: 24px;"></td></tr>
  </table>"""
        
        footer = cls._footer(f"Thank you for ordering, {user_name}!")
        
        html = cls._base_template(
            header + body + footer,
            f"Order #{order_id} confirmed - arriving in {estimated_time}"
        )
        
        plain = f"""Order Confirmed! ✓

Order #{order_id}
{f"Restaurant: {restaurant_name}" if restaurant_name else ""}
Estimated Delivery: {estimated_time}

ORDER DETAILS:
{items_text}
Subtotal: {subtotal}
Delivery: {delivery_fee}
TOTAL: {total}

DELIVERY ADDRESS:
{delivery_address}

Thank you, {user_name}!
© {cls._get_year()} Fudgo"""

        return {"subject": f"✅ Order Confirmed #{order_id} – Fudgo", "html": html, "plain": plain}

    # ============================================================
    # ORDER STATUS UPDATE - Timeline/progress style
    # ============================================================
    @classmethod
    def order_status_update(
        cls, user_name: str, order_id: str, status: str,
        status_message: str, estimated_time: str = None
    ) -> Dict[str, str]:
        """Order status - progress tracker design with dark mode"""
        
        statuses = {
            "confirmed": {"icon": "✓", "color": "#22c55e", "bg": "#dcfce7", "step": 1},
            "preparing": {"icon": "👨‍🍳", "color": "#f59e0b", "bg": "#fef3c7", "step": 2},
            "picked_up": {"icon": "📦", "color": "#3b82f6", "bg": "#dbeafe", "step": 3},
            "on_the_way": {"icon": "🚗", "color": "#8b5cf6", "bg": "#ede9fe", "step": 3},
            "delivered": {"icon": "🎉", "color": "#22c55e", "bg": "#dcfce7", "step": 4},
        }
        s = statuses.get(status.lower(), statuses["confirmed"])
        
        def step_html(step_num, label):
            if step_num < s["step"]:
                return f'<td align="center" style="width: 60px;"><div style="width: 32px; height: 32px; background: #22c55e; border-radius: 50%; color: white; line-height: 32px; font-weight: bold; margin: 0 auto;">✓</div><p style="font-size: 10px; color: #22c55e; margin: 4px 0 0;">{label}</p></td>'
            elif step_num == s["step"]:
                return f'<td align="center" style="width: 60px;"><div style="width: 32px; height: 32px; background: {s["color"]}; border-radius: 50%; color: white; line-height: 32px; font-weight: bold; margin: 0 auto; box-shadow: 0 0 0 4px {s["bg"]};">{step_num}</div><p style="font-size: 10px; color: {s["color"]}; margin: 4px 0 0; font-weight: bold;">{label}</p></td>'
            else:
                return f'<td align="center" style="width: 60px;"><div style="width: 32px; height: 32px; background: #e5e7eb; border-radius: 50%; color: #9ca3af; line-height: 32px; font-weight: bold; margin: 0 auto;">{step_num}</div><p style="font-size: 10px; color: #9ca3af; margin: 4px 0 0;">{label}</p></td>'
        
        def line_html(active):
            color = "#22c55e" if active else "#e5e7eb"
            return f'<td style="padding: 0 4px;"><div style="height: 3px; background: {color};"></div></td>'
        
        eta_html = f"""
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background: #f0fdf4; border-radius: 8px; padding: 16px; margin-top: 24px;">
        <tr><td align="center">
          <p style="color: #166534; font-weight: 600; margin: 0;">⏱️ ETA: {estimated_time}</p>
        </td></tr>
      </table>""" if estimated_time else ""
        
        header = cls._header(
            f"{status.replace('_', ' ').title()} {s['icon']}",
            f"Order #{order_id}",
            s['icon']
        )
        
        body = f"""
  <table style="max-width:600px; margin: 0 auto;" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr><td class="body__details body__background" style="border-radius: 16px; padding: 24px;">
      <table class="table__padded" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
        <tr><td align="center">
          <p style="color: #4b5563; font-size: 15px; line-height: 1.6; margin-bottom: 24px;">{status_message}</p>
          
          <!-- Progress Steps -->
          <table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin: 0 auto;">
            <tr>
              {step_html(1, "Confirmed")}
              {line_html(s["step"] > 1)}
              {step_html(2, "Preparing")}
              {line_html(s["step"] > 2)}
              {step_html(3, "On the way")}
              {line_html(s["step"] > 3)}
              {step_html(4, "Delivered")}
            </tr>
          </table>
          
          {eta_html}
          
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-top: 24px;">
            <tr><td align="center">
              <a href="#" class="btn-primary">Track Order 📍</a>
            </td></tr>
          </table>
        </td></tr>
      </table>
    </td></tr>
  </table>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr><td style="height: 24px;"></td></tr>
  </table>"""
        
        footer = cls._footer()
        
        html = cls._base_template(
            header + body + footer,
            f"Order #{order_id} - {status.replace('_', ' ').title()}"
        )
        
        eta_text = f"\nETA: {estimated_time}" if estimated_time else ""
        plain = f"""{status.replace('_', ' ').title()} - Order #{order_id}

{status_message}{eta_text}

Track your order in the Fudgo app.

© {cls._get_year()} Fudgo"""

        return {"subject": f"{s['icon']} {status.replace('_', ' ').title()} – Order #{order_id}", "html": html, "plain": plain}

    # ============================================================
    # ORDER DELIVERED - Success celebration with review CTA
    # ============================================================
    @classmethod
    def order_delivered(cls, user_name: str, order_id: str, restaurant_name: str, items: list = None) -> Dict[str, str]:
        """Order delivered - celebration with rating request and product images, dark mode"""
        
        # Build items gallery if items provided
        items_gallery = ""
        if items:
            items_html = ""
            for item in items[:4]:  # Show max 4 items
                image_url = item.get('image_url', '')
                name = item.get('name', '')
                if image_url:
                    items_html += f'<td style="padding: 4px;"><img src="{image_url}" alt="{name}" style="width: 70px; height: 70px; border-radius: 8px; object-fit: cover; border: 2px solid #fff; box-shadow: 0 2px 8px rgba(0,0,0,0.1);"></td>'
                else:
                    items_html += f'<td style="padding: 4px;"><div style="width: 70px; height: 70px; border-radius: 8px; background: #f0fdf4; border: 2px solid #fff; box-shadow: 0 2px 8px rgba(0,0,0,0.1); text-align: center; line-height: 70px; font-size: 28px;">🍽️</div></td>'
            
            items_gallery = f"""
          <p style="color: #6b7280; font-size: 13px; margin: 24px 0 12px;">Your order</p>
          <table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin: 0 auto;">
            <tr>{items_html}</tr>
          </table>"""
        
        header = cls._header(
            f"Enjoy Your Meal! 🍽️",
            f"Order #{order_id} delivered",
            "🍽️"
        )
        
        body = f"""
  <table style="max-width:600px; margin: 0 auto;" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr><td class="body__details body__background" style="border-radius: 16px; padding: 24px;">
      <table class="table__padded" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
        <tr><td align="center">
          <!-- Restaurant Card -->
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background: #f9fafb; border-radius: 12px; padding: 20px; margin-bottom: 16px;">
            <tr><td align="center">
              <p style="color: #6b7280; font-size: 13px; margin: 0 0 4px;">Delivered from</p>
              <p style="color: #1f2937; font-size: 18px; font-weight: 600; margin: 0;">🏪 {restaurant_name}</p>
            </td></tr>
          </table>
          
          {items_gallery}
          
          <!-- Rating Section -->
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin: 32px 0;">
            <tr><td align="center">
              <p style="color: #1f2937; font-size: 18px; font-weight: 600; margin: 0 0 16px;">How was your food?</p>
              <p style="font-size: 36px; letter-spacing: 8px; margin: 0;">⭐⭐⭐⭐⭐</p>
            </td></tr>
          </table>
          
          <a href="#" class="btn-primary" style="background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%); padding: 16px 40px; font-size: 16px;">Rate Your Order</a>
          <p style="margin-top: 20px;"><a href="#" style="color: #22c55e; font-weight: 600; font-size: 15px;">🔄 Order Again</a></p>
        </td></tr>
      </table>
    </td></tr>
  </table>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr><td style="height: 24px;"></td></tr>
  </table>"""
        
        footer = cls._footer(f"Thanks for choosing Fudgo, {user_name}!")
        
        html = cls._base_template(
            header + body + footer,
            f"Your order from {restaurant_name} has been delivered!"
        )
        
        items_text = ""
        if items:
            items_text = "\nYour order:\n" + "\n".join([f"  • {item.get('name', '')}" for item in items[:4]])
        
        plain = f"""🍽️ Enjoy Your Meal!

Order #{order_id} has been delivered from {restaurant_name}.
{items_text}

How was your food? Rate your order in the Fudgo app!

Thanks for choosing Fudgo, {user_name}!
© {cls._get_year()} Fudgo"""

        return {"subject": f"🍽️ Delivered! Rate Your Order – #{order_id}", "html": html, "plain": plain}

    # ============================================================
    # PROMOTION DISCOUNT - Bold food delivery promo (index.html style)
    # ============================================================
    
    PROMO_STYLES = """
    @media only screen and (min-width: 620px) {
      .u-row { width: 600px !important; }
      .u-row .u-col { vertical-align: top; }
      .u-row .u-col-50 { width: 300px !important; }
      .u-row .u-col-100 { width: 600px !important; }
    }
    @media only screen and (max-width: 620px) {
      .u-row-container { max-width: 100% !important; padding: 0 !important; }
      .u-row { width: 100% !important; }
      .u-row .u-col { display: block !important; width: 100% !important; min-width: 320px !important; max-width: 100% !important; }
      .u-row .u-col > div { margin: 0 auto; }
      .food-item-cell { width: 50% !important; }
    }
    body { margin: 0; padding: 0; }
    table, td, tr { border-collapse: collapse; vertical-align: top; }
    .ie-container table, .mso-container table { table-layout: fixed; }
    * { line-height: inherit; }
    a[x-apple-data-detectors=true] { color: inherit !important; text-decoration: none !important; }
    """
    
    @classmethod
    def promotion_discount(
        cls, user_name: str, discount_amount: str,
        description: str, expiry_date: str,
        hero_image_url: str = None,
        hero_title: str = "HUNGRY?",
        hero_subtitle: str = "Let us deliver the best food",
        food_items: list = None,
        restaurants: list = None,
        min_order: str = None,
        cta_text: str = "Order Now",
        cta_link: str = "https://fudgo.com",
        contact_phone: str = None,
        contact_address: str = None,
        contact_hours: str = None
    ) -> Dict[str, str]:
        """
        Promotion email - vibrant food delivery style matching index.html design.
        
        Args:
            user_name: Customer name
            discount_amount: e.g., "20%", "$10"
            description: Promotion description
            expiry_date: When the promotion expires
            hero_image_url: Background image for hero section
            hero_title: Main headline (default: "HUNGRY?")
            hero_subtitle: Subtitle text
            food_items: List of dicts [{name, image_url, price, original_price}] - MAX 4 displayed
            restaurants: List of dicts [{name, image_url, cuisines, link}] - restaurant cover images
            min_order: Minimum order requirement
            cta_text: Call-to-action button text
            cta_link: CTA button link
            contact_phone: Contact phone number
            contact_address: Business address
            contact_hours: Operating hours
        """
        
        # Default hero image
        default_hero = "https://cdn.templates.unlayer.com/assets/1638077528255-f.jpg"
        hero_bg = hero_image_url or default_hero
        
        # Build header section (logo + phone)
        phone_display = contact_phone or "+1 234-567-890"
        header_section = f'''
<div class="u-row-container" style="padding: 0px; background-color: transparent;">
  <div class="u-row" style="margin: 0 auto; min-width: 320px; max-width: 600px; overflow-wrap: break-word; word-wrap: break-word; word-break: break-word; background-color: #22c55e;">
    <div style="border-collapse: collapse; display: table; width: 100%; height: 100%; background-color: transparent;">
      <!--[if (mso)|(IE)]><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr><td style="padding: 0px; background-color: transparent;" bgcolor="transparent"><table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" bgcolor="#22c55e"><tr style="background-color: #22c55e;"><![endif]-->
      <!--[if (mso)|(IE)]><td align="center" width="300" style="width: 300px; padding: 0px; border: 0px;" valign="top"><![endif]-->
      <div class="u-col u-col-50" style="max-width: 320px; min-width: 300px; display: table-cell; vertical-align: top;">
        <div style="height: 100%; width: 100% !important;">
          <div style="box-sizing: border-box; height: 100%; padding: 0px;">
            <table style="font-family: arial, helvetica, sans-serif;" role="presentation" cellpadding="0" cellspacing="0" width="100%" border="0">
              <tbody>
                <tr>
                  <td style="overflow-wrap: break-word; word-break: break-word; padding: 15px 10px; font-family: arial, helvetica, sans-serif;" align="left">
                    <div style="font-size: 24px; color: #ffffff; line-height: 100%; text-align: left; word-wrap: break-word;">
                      <span style="font-family: Rubik, sans-serif; font-weight: bold;">🍔 Fudgo</span>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
      <!--[if (mso)|(IE)]></td><td align="center" width="300" style="width: 300px; padding: 0px; border: 0px;" valign="top"><![endif]-->
      <div class="u-col u-col-50" style="max-width: 320px; min-width: 300px; display: table-cell; vertical-align: top;">
        <div style="height: 100%; width: 100% !important;">
          <div style="box-sizing: border-box; height: 100%; padding: 0px;">
            <table style="font-family: arial, helvetica, sans-serif;" role="presentation" cellpadding="0" cellspacing="0" width="100%" border="0">
              <tbody>
                <tr>
                  <td style="overflow-wrap: break-word; word-break: break-word; padding: 15px 10px; font-family: arial, helvetica, sans-serif;" align="left">
                    <div style="font-size: 16px; color: #ffffff; line-height: 100%; text-align: right; word-wrap: break-word;">
                      <span style="font-family: Raleway, sans-serif;">{phone_display}</span>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
      <!--[if (mso)|(IE)]></td></tr></table></td></tr></table><![endif]-->
    </div>
  </div>
</div>'''
        
        # Build hero section with background image and overlay pattern
        # SVG wave pattern encoded as data URI for email compatibility
        wave_svg = "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 600 44' preserveAspectRatio='none'%3E%3Cpath fill='%23ffffff' d='M0,22 Q150,44 300,22 T600,22 L600,44 L0,44 Z'/%3E%3C/svg%3E"
        
        hero_section = f'''
<!--[if gte mso 9]>
<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="600">
  <tr>
    <td background="{hero_bg}" valign="top">
      <v:rect xmlns:v="urn:schemas-microsoft-com:vml" fill="true" stroke="false" style="width:600px;">
        <v:fill type="frame" src="{hero_bg}" />
        <v:textbox style="mso-fit-shape-to-text:true" inset="0,0,0,0">
<![endif]-->
<div class="u-row-container" style="padding: 0px; background-color: transparent;">
  <div class="u-row" style="margin: 0 auto; min-width: 320px; max-width: 600px; overflow-wrap: break-word; word-wrap: break-word; word-break: break-word; background-color: #22c55e;">
    <div style="border-collapse: collapse; display: table; width: 100%; height: 100%; background-image: url('{hero_bg}'); background-repeat: no-repeat; background-position: center center; background-size: cover; background-color: #22c55e;">
      <!--[if (mso)|(IE)]><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr><td style="padding: 0px; background-color: transparent;"><table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%"><tr style="background-image: url('{hero_bg}'); background-repeat: no-repeat; background-position: center center;"><![endif]-->
      <!--[if (mso)|(IE)]><td align="center" width="600" style="width: 600px; padding: 0px; border: 0px;" valign="top"><![endif]-->
      <div class="u-col u-col-100" style="max-width: 320px; min-width: 600px; display: table-cell; vertical-align: top;">
        <div style="height: 100%; width: 100% !important;">
          <div style="box-sizing: border-box; height: 100%; padding: 0px;">
            <!-- Spacer to push content down and show background image -->
            <table style="font-family: arial, helvetica, sans-serif;" role="presentation" cellpadding="0" cellspacing="0" width="100%" border="0">
              <tbody>
                <tr>
                  <td style="padding: 120px 10px 0px; font-family: arial, helvetica, sans-serif;" align="left">
                    &nbsp;
                  </td>
                </tr>
              </tbody>
            </table>
            <!-- Text overlay with semi-transparent background for readability -->
            <table style="font-family: arial, helvetica, sans-serif;" role="presentation" cellpadding="0" cellspacing="0" width="100%" border="0">
              <tbody>
                <tr>
                  <td style="overflow-wrap: break-word; word-break: break-word; padding: 30px 20px; font-family: arial, helvetica, sans-serif; background: linear-gradient(180deg, rgba(34,197,94,0.85) 0%, rgba(34,197,94,0.95) 100%); background-color: rgba(34,197,94,0.9);" align="left">
                    <div style="font-size: 48px; color: #ffffff; line-height: 100%; text-align: center; word-wrap: break-word; text-shadow: 2px 2px 8px rgba(0,0,0,0.4);">
                      <span style="font-family: Rubik, sans-serif;"><strong>{hero_title}</strong></span>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
            <table style="font-family: arial, helvetica, sans-serif;" role="presentation" cellpadding="0" cellspacing="0" width="100%" border="0">
              <tbody>
                <tr>
                  <td style="overflow-wrap: break-word; word-break: break-word; padding: 0px 20px 15px; font-family: arial, helvetica, sans-serif; background-color: rgba(34,197,94,0.9);" align="left">
                    <div style="font-size: 28px; color: #ffffff; line-height: 130%; text-align: center; word-wrap: break-word; text-shadow: 1px 1px 4px rgba(0,0,0,0.3);">
                      <span style="font-family: Raleway, sans-serif;"><strong>{hero_subtitle}</strong></span>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
            <table style="font-family: arial, helvetica, sans-serif;" role="presentation" cellpadding="0" cellspacing="0" width="100%" border="0">
              <tbody>
                <tr>
                  <td style="overflow-wrap: break-word; word-break: break-word; padding: 20px 10px 40px; font-family: arial, helvetica, sans-serif; background-color: rgba(34,197,94,0.9);" align="left">
                    <div align="center">
                      <!--[if mso]><table role="presentation" border="0" cellspacing="0" cellpadding="0"><tr><td align="center" bgcolor="#ffffff" style="padding:12px 30px;" valign="top"><![endif]-->
                      <a href="{cta_link}" target="_blank" style="box-sizing: border-box; display: inline-block; text-decoration: none; text-align: center; color: #22c55e; background-color: #ffffff; border-radius: 4px; font-size: 16px; padding: 14px 35px; font-family: Raleway, sans-serif; font-weight: bold; border: 1px solid #ffffff; border-width: 1px 3px 3px 1px; box-shadow: 2px 2px 4px rgba(0,0,0,0.2);">
                        {cta_text.upper()}
                      </a>
                      <!--[if mso]></td></tr></table><![endif]-->
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
      <!--[if (mso)|(IE)]></td></tr></table></td></tr></table><![endif]-->
    </div>
  </div>
</div>
<!--[if gte mso 9]>
        </v:textbox>
      </v:rect>
    </td>
  </tr>
</table>
<![endif]-->
<!-- Wave pattern divider -->
<div class="u-row-container" style="padding: 0px; background-color: transparent;">
  <div class="u-row" style="margin: 0 auto; min-width: 320px; max-width: 600px; overflow-wrap: break-word; word-wrap: break-word; word-break: break-word; background-color: #22c55e;">
    <div style="border-collapse: collapse; display: table; width: 100%; height: 100%; background-color: transparent;">
      <!--[if (mso)|(IE)]><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr><td style="padding: 0px; background-color: transparent;"><table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" bgcolor="#22c55e"><tr style="background-color: #22c55e;"><![endif]-->
      <!--[if (mso)|(IE)]><td align="center" width="600" style="width: 600px; padding: 0px; border: 0px;" valign="top"><![endif]-->
      <div class="u-col u-col-100" style="max-width: 320px; min-width: 600px; display: table-cell; vertical-align: top;">
        <div style="height: 100%; width: 100% !important;">
          <div style="box-sizing: border-box; height: 100%; padding: 0px;">
            <table style="font-family: arial, helvetica, sans-serif;" role="presentation" cellpadding="0" cellspacing="0" width="100%" border="0">
              <tbody>
                <tr>
                  <td style="overflow-wrap: break-word; word-break: break-word; padding: 0px; font-family: arial, helvetica, sans-serif;" align="left">
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                      <tr>
                        <td style="padding-right: 0px; padding-left: 0px;" align="center">
                          <img align="center" border="0" src="{wave_svg}" alt="" style="outline: none; text-decoration: none; -ms-interpolation-mode: bicubic; clear: both; display: inline-block !important; border: none; height: auto; float: none; width: 100%; max-width: 600px;" width="600" height="44"/>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
      <!--[if (mso)|(IE)]></td></tr></table></td></tr></table><![endif]-->
    </div>
  </div>
</div>'''
        
        # Build food items section (max 4 items in 2x2 grid)
        food_section = ""
        if food_items:
            items = food_items[:4]  # Limit to 4 items
            
            # Section header
            food_section = '''
<div class="u-row-container" style="padding: 0px; background-color: transparent;">
  <div class="u-row" style="margin: 0 auto; min-width: 320px; max-width: 600px; overflow-wrap: break-word; word-wrap: break-word; word-break: break-word; background-color: #ffffff;">
    <div style="border-collapse: collapse; display: table; width: 100%; height: 100%; background-color: transparent;">
      <!--[if (mso)|(IE)]><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr><td style="padding: 0px; background-color: transparent;"><table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" bgcolor="#ffffff"><tr style="background-color: #ffffff;"><![endif]-->
      <!--[if (mso)|(IE)]><td align="center" width="600" style="width: 600px; padding: 0px; border: 0px;" valign="top"><![endif]-->
      <div class="u-col u-col-100" style="max-width: 320px; min-width: 600px; display: table-cell; vertical-align: top;">
        <div style="height: 100%; width: 100% !important;">
          <div style="box-sizing: border-box; height: 100%; padding: 0px;">
            <table style="font-family: arial, helvetica, sans-serif;" role="presentation" cellpadding="0" cellspacing="0" width="100%" border="0">
              <tbody>
                <tr>
                  <td style="overflow-wrap: break-word; word-break: break-word; padding: 40px 10px 10px; font-family: arial, helvetica, sans-serif;" align="left">
                    <div style="font-size: 14px; color: #22c55e; line-height: 100%; text-align: center; word-wrap: break-word;">
                      <span style="font-family: Raleway, sans-serif; font-size: 16px;">GREAT DEALS</span>
                    </div>
                  </td>
                </tr>
                <tr>
                  <td style="overflow-wrap: break-word; word-break: break-word; padding: 0px 10px 25px; font-family: arial, helvetica, sans-serif;" align="left">
                    <div style="font-size: 34px; color: #5f5f5f; line-height: 100%; text-align: center; word-wrap: break-word;">
                      <span style="font-family: Rubik, sans-serif;"><strong>Featured Items</strong></span>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
      <!--[if (mso)|(IE)]></td></tr></table></td></tr></table><![endif]-->
    </div>
  </div>
</div>'''
            
            # Build 2x2 grid of food items
            for i in range(0, len(items), 2):
                row_items = items[i:i+2]
                food_section += '''
<div class="u-row-container" style="padding: 0px; background-color: transparent;">
  <div class="u-row" style="margin: 0 auto; min-width: 320px; max-width: 600px; overflow-wrap: break-word; word-wrap: break-word; word-break: break-word; background-color: #ffffff;">
    <div style="border-collapse: collapse; display: table; width: 100%; height: 100%; background-color: transparent;">
      <!--[if (mso)|(IE)]><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr><td style="padding: 0px; background-color: transparent;"><table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" bgcolor="#ffffff"><tr style="background-color: #ffffff;"><![endif]-->'''
                
                for item in row_items:
                    name = item.get('name', 'Food Item')
                    image_url = item.get('image_url', '')
                    price = item.get('price', '')
                    original_price = item.get('original_price', '')
                    
                    price_html = ""
                    if original_price:
                        price_html = f'''<span style="text-decoration: line-through; color: #9ca3af; font-size: 14px; margin-right: 8px;">{original_price}</span><span style="color: #22c55e; font-weight: bold; font-size: 18px;">{price}</span>'''
                    elif price:
                        price_html = f'''<span style="color: #22c55e; font-weight: bold; font-size: 18px;">{price}</span>'''
                    
                    food_section += f'''
      <!--[if (mso)|(IE)]><td align="center" width="299" style="width: 299px; padding: 0px; border-right: 1px solid #22c55e; border-top: 0px; border-left: 0px; border-bottom: 0px;" valign="top"><![endif]-->
      <div class="u-col u-col-50 food-item-cell" style="max-width: 320px; min-width: 300px; display: table-cell; vertical-align: top;">
        <div style="height: 100%; width: 100% !important;">
          <div style="box-sizing: border-box; height: 100%; padding: 0px; border-right: 1px solid #f0f0f0;">
            <table style="font-family: arial, helvetica, sans-serif;" role="presentation" cellpadding="0" cellspacing="0" width="100%" border="0">
              <tbody>
                <tr>
                  <td style="overflow-wrap: break-word; word-break: break-word; padding: 10px; font-family: arial, helvetica, sans-serif;" align="left">
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                      <tr>
                        <td style="padding-right: 0px; padding-left: 0px;" align="center">
                          <img align="center" border="0" src="{image_url}" alt="{name}" title="{name}" style="outline: none; text-decoration: none; clear: both; display: inline-block !important; border: none; height: auto; float: none; width: 100%; max-width: 260px; border-radius: 8px;" width="260"/>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </tbody>
            </table>
            <table style="font-family: arial, helvetica, sans-serif;" role="presentation" cellpadding="0" cellspacing="0" width="100%" border="0">
              <tbody>
                <tr>
                  <td style="overflow-wrap: break-word; word-break: break-word; padding: 5px 10px 20px; font-family: arial, helvetica, sans-serif;" align="left">
                    <div style="font-size: 22px; color: #5f5f5f; line-height: 100%; text-align: center; word-wrap: break-word;">
                      <span style="font-family: Rubik, sans-serif;"><strong>{name}</strong></span>
                    </div>
                    <div style="font-size: 14px; color: #5f5f5f; line-height: 150%; text-align: center; word-wrap: break-word; margin-top: 8px;">
                      {price_html}
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
      <!--[if (mso)|(IE)]></td><![endif]-->'''
                
                food_section += '''
      <!--[if (mso)|(IE)]></tr></table></td></tr></table><![endif]-->
    </div>
  </div>
</div>'''
        
        # Build restaurants section
        restaurant_section = ""
        if restaurants:
            restaurant_section = '''
<div class="u-row-container" style="padding: 0px; background-color: transparent;">
  <div class="u-row" style="margin: 0 auto; min-width: 320px; max-width: 600px; overflow-wrap: break-word; word-wrap: break-word; word-break: break-word; background-color: #f1f1f1;">
    <div style="border-collapse: collapse; display: table; width: 100%; height: 100%; background-color: transparent;">
      <!--[if (mso)|(IE)]><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr><td style="padding: 0px; background-color: transparent;"><table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" bgcolor="#f1f1f1"><tr style="background-color: #f1f1f1;"><![endif]-->
      <!--[if (mso)|(IE)]><td align="center" width="600" style="width: 600px; padding: 0px; border: 0px;" valign="top"><![endif]-->
      <div class="u-col u-col-100" style="max-width: 320px; min-width: 600px; display: table-cell; vertical-align: top;">
        <div style="height: 100%; width: 100% !important;">
          <div style="box-sizing: border-box; height: 100%; padding: 0px;">
            <table style="font-family: arial, helvetica, sans-serif;" role="presentation" cellpadding="0" cellspacing="0" width="100%" border="0">
              <tbody>
                <tr>
                  <td style="overflow-wrap: break-word; word-break: break-word; padding: 40px 10px 10px; font-family: arial, helvetica, sans-serif;" align="left">
                    <div style="font-size: 14px; color: #22c55e; line-height: 100%; text-align: center; word-wrap: break-word;">
                      <span style="font-family: Raleway, sans-serif; font-size: 16px;">ENJOY IT</span>
                    </div>
                  </td>
                </tr>
                <tr>
                  <td style="overflow-wrap: break-word; word-break: break-word; padding: 0px 10px 25px; font-family: arial, helvetica, sans-serif;" align="left">
                    <div style="font-size: 34px; color: #4e4e4e; line-height: 100%; text-align: center; word-wrap: break-word;">
                      <span style="font-family: Rubik, sans-serif;"><strong>Top Restaurants</strong></span>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
      <!--[if (mso)|(IE)]></td></tr></table></td></tr></table><![endif]-->
    </div>
  </div>
</div>'''
            
            # Restaurant cards (2 per row)
            for i in range(0, len(restaurants[:4]), 2):
                row_restaurants = restaurants[i:i+2]
                restaurant_section += '''
<div class="u-row-container" style="padding: 0px; background-color: transparent;">
  <div class="u-row" style="margin: 0 auto; min-width: 320px; max-width: 600px; overflow-wrap: break-word; word-wrap: break-word; word-break: break-word; background-color: #f1f1f1;">
    <div style="border-collapse: collapse; display: table; width: 100%; height: 100%; background-color: transparent;">
      <!--[if (mso)|(IE)]><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr><td style="padding: 0px; background-color: transparent;"><table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" bgcolor="#f1f1f1"><tr style="background-color: #f1f1f1;"><![endif]-->'''
                
                for rest in row_restaurants:
                    name = rest.get('name', 'Restaurant')
                    image_url = rest.get('image_url', '')
                    cuisines = rest.get('cuisines', '')
                    link = rest.get('link', cta_link)
                    
                    restaurant_section += f'''
      <!--[if (mso)|(IE)]><td align="center" width="300" style="width: 300px; padding: 0px; border: 0px;" valign="top"><![endif]-->
      <div class="u-col u-col-50" style="max-width: 320px; min-width: 300px; display: table-cell; vertical-align: top;">
        <div style="height: 100%; width: 100% !important;">
          <div style="box-sizing: border-box; height: 100%; padding: 0px;">
            <table style="font-family: arial, helvetica, sans-serif;" role="presentation" cellpadding="0" cellspacing="0" width="100%" border="0">
              <tbody>
                <tr>
                  <td style="overflow-wrap: break-word; word-break: break-word; padding: 0px; font-family: arial, helvetica, sans-serif;" align="left">
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                      <tr>
                        <td style="padding-right: 0px; padding-left: 0px;" align="center">
                          <img align="center" border="0" src="{image_url}" alt="{name}" title="{name}" style="outline: none; text-decoration: none; clear: both; display: inline-block !important; border: none; height: auto; float: none; width: 100%; max-width: 300px;" width="300"/>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </tbody>
            </table>
            <table style="font-family: arial, helvetica, sans-serif;" role="presentation" cellpadding="0" cellspacing="0" width="100%" border="0">
              <tbody>
                <tr>
                  <td style="overflow-wrap: break-word; word-break: break-word; padding: 16px 10px 9px; font-family: arial, helvetica, sans-serif;" align="left">
                    <div style="font-size: 24px; color: #474747; line-height: 100%; text-align: center; word-wrap: break-word;">
                      <span style="font-family: Rubik, sans-serif;">{name}</span>
                    </div>
                  </td>
                </tr>
                <tr>
                  <td style="overflow-wrap: break-word; word-break: break-word; padding: 5px 10px 15px; font-family: arial, helvetica, sans-serif;" align="left">
                    <div style="font-size: 14px; color: #22c55e; line-height: 100%; text-align: center; word-wrap: break-word;">
                      <span style="font-family: Raleway, sans-serif; font-size: 14px;">{cuisines}</span>
                    </div>
                  </td>
                </tr>
                <tr>
                  <td style="overflow-wrap: break-word; word-break: break-word; padding: 10px 10px 35px; font-family: arial, helvetica, sans-serif;" align="left">
                    <div align="center">
                      <a href="{link}" target="_blank" style="box-sizing: border-box; display: inline-block; text-decoration: none; text-align: center; color: #ffffff; background-color: #22c55e; border-radius: 4px; font-size: 14px; padding: 12px 25px; font-family: Raleway, sans-serif;">
                        Order Now
                      </a>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
      <!--[if (mso)|(IE)]></td><![endif]-->'''
                
                restaurant_section += '''
      <!--[if (mso)|(IE)]></tr></table></td></tr></table><![endif]-->
    </div>
  </div>
</div>'''
        
        # Build expiry notice
        expiry_section = f'''
<div class="u-row-container" style="padding: 0px; background-color: transparent;">
  <div class="u-row" style="margin: 0 auto; min-width: 320px; max-width: 600px; overflow-wrap: break-word; word-wrap: break-word; word-break: break-word; background-color: #fef3c7;">
    <div style="border-collapse: collapse; display: table; width: 100%; height: 100%; background-color: transparent;">
      <!--[if (mso)|(IE)]><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr><td style="padding: 0px; background-color: transparent;"><table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" bgcolor="#fef3c7"><tr style="background-color: #fef3c7;"><![endif]-->
      <!--[if (mso)|(IE)]><td align="center" width="600" style="width: 600px; padding: 0px; border: 0px;" valign="top"><![endif]-->
      <div class="u-col u-col-100" style="max-width: 320px; min-width: 600px; display: table-cell; vertical-align: top;">
        <div style="height: 100%; width: 100% !important;">
          <div style="box-sizing: border-box; height: 100%; padding: 0px;">
            <table style="font-family: arial, helvetica, sans-serif;" role="presentation" cellpadding="0" cellspacing="0" width="100%" border="0">
              <tbody>
                <tr>
                  <td style="overflow-wrap: break-word; word-break: break-word; padding: 20px 10px; font-family: arial, helvetica, sans-serif;" align="left">
                    <div style="font-size: 16px; color: #92400e; line-height: 100%; text-align: center; word-wrap: break-word;">
                      <span style="font-family: Raleway, sans-serif;"><strong>⏰ {discount_amount} OFF - Expires: {expiry_date}</strong></span>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
      <!--[if (mso)|(IE)]></td></tr></table></td></tr></table><![endif]-->
    </div>
  </div>
</div>'''
        
        # Build footer section
        address_display = contact_address or "Your City, Your Street"
        hours_display = contact_hours or "Mon - Sun: 10AM - 11PM"
        
        footer_section = f'''
<div class="u-row-container" style="padding: 0px; background-color: transparent;">
  <div class="u-row" style="margin: 0 auto; min-width: 320px; max-width: 600px; overflow-wrap: break-word; word-wrap: break-word; word-break: break-word; background-color: #166534;">
    <div style="border-collapse: collapse; display: table; width: 100%; height: 100%; background-color: transparent;">
      <!--[if (mso)|(IE)]><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr><td style="padding: 0px; background-color: transparent;"><table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" bgcolor="#166534"><tr style="background-color: #166534;"><![endif]-->
      <!--[if (mso)|(IE)]><td align="center" width="300" style="width: 300px; padding: 0px; border: 0px;" valign="top"><![endif]-->
      <div class="u-col u-col-50" style="max-width: 320px; min-width: 300px; display: table-cell; vertical-align: top;">
        <div style="height: 100%; width: 100% !important;">
          <div style="box-sizing: border-box; height: 100%; padding: 0px;">
            <table style="font-family: arial, helvetica, sans-serif;" role="presentation" cellpadding="0" cellspacing="0" width="100%" border="0">
              <tbody>
                <tr>
                  <td style="overflow-wrap: break-word; word-break: break-word; padding: 40px 10px 6px; font-family: arial, helvetica, sans-serif;" align="left">
                    <div style="font-size: 26px; color: #ffffff; line-height: 100%; text-align: center; word-wrap: break-word;">
                      <span style="font-family: Rubik, sans-serif;"><strong>Contact Us</strong></span>
                    </div>
                  </td>
                </tr>
                <tr>
                  <td style="overflow-wrap: break-word; word-break: break-word; padding: 8px 10px 0px; font-family: arial, helvetica, sans-serif;" align="left">
                    <div style="font-size: 14px; color: #bbf7d0; line-height: 150%; text-align: center; word-wrap: break-word;">
                      <span style="font-family: Raleway, sans-serif; font-size: 14px;">{address_display}</span>
                    </div>
                  </td>
                </tr>
                <tr>
                  <td style="overflow-wrap: break-word; word-break: break-word; padding: 8px 10px 0px; font-family: arial, helvetica, sans-serif;" align="left">
                    <div style="font-size: 14px; color: #bbf7d0; line-height: 150%; text-align: center; word-wrap: break-word;">
                      <span style="font-family: Raleway, sans-serif; font-size: 14px;">{hours_display}</span>
                    </div>
                  </td>
                </tr>
                <tr>
                  <td style="overflow-wrap: break-word; word-break: break-word; padding: 8px 10px 30px; font-family: arial, helvetica, sans-serif;" align="left">
                    <div style="font-size: 14px; color: #bbf7d0; line-height: 150%; text-align: center; word-wrap: break-word;">
                      <span style="font-family: Raleway, sans-serif; font-size: 14px;">{phone_display}</span>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
      <!--[if (mso)|(IE)]></td><td align="center" width="300" style="width: 300px; padding: 0px; border: 0px;" valign="top"><![endif]-->
      <div class="u-col u-col-50" style="max-width: 320px; min-width: 300px; display: table-cell; vertical-align: top;">
        <div style="height: 100%; width: 100% !important;">
          <div style="box-sizing: border-box; height: 100%; padding: 0px;">
            <table style="font-family: arial, helvetica, sans-serif;" role="presentation" cellpadding="0" cellspacing="0" width="100%" border="0">
              <tbody>
                <tr>
                  <td style="overflow-wrap: break-word; word-break: break-word; padding: 40px 10px 6px; font-family: arial, helvetica, sans-serif;" align="left">
                    <div style="font-size: 26px; color: #ffffff; line-height: 100%; text-align: center; word-wrap: break-word;">
                      <span style="font-family: Rubik, sans-serif;"><strong>Quick Links</strong></span>
                    </div>
                  </td>
                </tr>
                <tr>
                  <td style="overflow-wrap: break-word; word-break: break-word; padding: 10px; font-family: arial, helvetica, sans-serif;" align="left">
                    <div style="text-align: center;">
                      <a href="{cta_link}" style="padding: 5px 15px; display: inline-block; color: #bbf7d0; font-family: arial, helvetica, sans-serif; font-size: 14px; text-decoration: none;">Order Now</a>
                      <a href="#" style="padding: 5px 15px; display: inline-block; color: #bbf7d0; font-family: arial, helvetica, sans-serif; font-size: 14px; text-decoration: none;">Contact</a>
                    </div>
                  </td>
                </tr>
                <tr>
                  <td style="overflow-wrap: break-word; word-break: break-word; padding: 10px 10px 30px; font-family: arial, helvetica, sans-serif;" align="left">
                    <div style="text-align: center;">
                      <a href="#" style="padding: 5px 15px; display: inline-block; color: #bbf7d0; font-family: arial, helvetica, sans-serif; font-size: 14px; text-decoration: none;">Unsubscribe</a>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
      <!--[if (mso)|(IE)]></td></tr></table></td></tr></table><![endif]-->
    </div>
  </div>
</div>
<div class="u-row-container" style="padding: 0px; background-color: transparent;">
  <div class="u-row" style="margin: 0 auto; min-width: 320px; max-width: 600px; overflow-wrap: break-word; word-wrap: break-word; word-break: break-word; background-color: #15803d;">
    <div style="border-collapse: collapse; display: table; width: 100%; height: 100%; background-color: transparent;">
      <!--[if (mso)|(IE)]><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr><td style="padding: 0px; background-color: transparent;"><table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" bgcolor="#15803d"><tr style="background-color: #15803d;"><![endif]-->
      <!--[if (mso)|(IE)]><td align="center" width="600" style="width: 600px; padding: 0px; border: 0px;" valign="top"><![endif]-->
      <div class="u-col u-col-100" style="max-width: 320px; min-width: 600px; display: table-cell; vertical-align: top;">
        <div style="height: 100%; width: 100% !important;">
          <div style="box-sizing: border-box; height: 100%; padding: 0px;">
            <table style="font-family: arial, helvetica, sans-serif;" role="presentation" cellpadding="0" cellspacing="0" width="100%" border="0">
              <tbody>
                <tr>
                  <td style="overflow-wrap: break-word; word-break: break-word; padding: 20px 10px; font-family: arial, helvetica, sans-serif;" align="left">
                    <div style="font-size: 14px; color: #bbf7d0; line-height: 150%; text-align: center; word-wrap: break-word;">
                      <span style="font-family: Raleway, sans-serif; font-size: 14px;">©️ {cls._get_year()} Fudgo. All rights reserved.</span>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
      <!--[if (mso)|(IE)]></td></tr></table></td></tr></table><![endif]-->
    </div>
  </div>
</div>'''
        
        # Assemble full HTML email
        html = f'''<!DOCTYPE HTML PUBLIC "-//W3C//DTD XHTML 1.0 Transitional //EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
<!--[if gte mso 9]>
<xml>
  <o:OfficeDocumentSettings>
    <o:AllowPNG/>
    <o:PixelsPerInch>96</o:PixelsPerInch>
  </o:OfficeDocumentSettings>
</xml>
<![endif]-->
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="x-apple-disable-message-reformatting">
  <!--[if !mso]><!--><meta http-equiv="X-UA-Compatible" content="IE=edge"><!--<![endif]-->
  <title>Fudgo - {discount_amount} OFF</title>
  <style type="text/css">
    {cls.PROMO_STYLES}
  </style>
  <!--[if !mso]><!--><link href="https://fonts.googleapis.com/css?family=Raleway:400,700&display=swap" rel="stylesheet" type="text/css"><link href="https://fonts.googleapis.com/css?family=Rubik:400,700&display=swap" rel="stylesheet" type="text/css"><!--<![endif]-->
</head>
<body class="clean-body u_body" style="margin: 0; padding: 0; -webkit-text-size-adjust: 100%; background-color: #f0fdf4; color: #000000;">
  <!--[if IE]><div class="ie-container"><![endif]-->
  <!--[if mso]><div class="mso-container"><![endif]-->
  <table role="presentation" id="u_body" style="border-collapse: collapse; table-layout: fixed; border-spacing: 0; mso-table-lspace: 0pt; mso-table-rspace: 0pt; vertical-align: top; min-width: 320px; Margin: 0 auto; background-color: #f0fdf4; width: 100%;" cellpadding="0" cellspacing="0">
  <tbody>
  <tr style="vertical-align: top">
    <td style="word-break: break-word; border-collapse: collapse !important; vertical-align: top;">
    <!--[if (mso)|(IE)]><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr><td align="center" style="background-color: #f0fdf4;" bgcolor="#f0fdf4"><![endif]-->
    
{header_section}
{hero_section}
{food_section}
{expiry_section}
{restaurant_section}
{footer_section}

    <!--[if (mso)|(IE)]></td></tr></table><![endif]-->
    </td>
  </tr>
  </tbody>
  </table>
  <!--[if mso]></div><![endif]-->
  <!--[if IE]></div><![endif]-->
</body>
</html>'''
        
        # Build plain text version
        items_text = ""
        if food_items:
            items_text = "\n\n🍽️ FEATURED ITEMS:\n" + "\n".join([
                f"  • {item.get('name', '')} - {item.get('price', '')}" 
                for item in food_items[:4]
            ])
        
        restaurants_text = ""
        if restaurants:
            restaurants_text = "\n\n🏪 TOP RESTAURANTS:\n" + "\n".join([
                f"  • {r.get('name', '')} ({r.get('cuisines', '')})" 
                for r in restaurants[:4]
            ])
        
        min_text = f"\nMin. order: {min_order}" if min_order else ""
        
        plain = f"""🍔 FUDGO - {discount_amount} OFF!

{hero_title}
{hero_subtitle}

{description}{items_text}{restaurants_text}

⏰ Offer expires: {expiry_date}{min_text}

Order now at {cta_link}

────────────────────
📍 {address_display}
🕐 {hours_display}
📞 {phone_display}

© {cls._get_year()} Fudgo. All rights reserved.
To unsubscribe, visit our website."""
        
        return {
            "subject": f"🍔 {discount_amount} OFF - {hero_title} Fudgo Has You Covered!",
            "html": html,
            "plain": plain
        }

    # ============================================================
    # WELCOME PROMO - Gift themed, first order discount
    # ============================================================
    @classmethod
    def welcome_promo(cls, user_name: str, promo_code: str, discount_amount: str) -> Dict[str, str]:
        """Welcome promo - gift box themed with dark mode"""
        
        header = cls._header(
            f"A Gift For You! 🎁",
            "Welcome to the Fudgo family",
            "🎁"
        )
        
        body = f"""
  <table style="max-width:600px; margin: 0 auto;" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr><td class="body__details body__background" style="border-radius: 16px; padding: 24px;">
      <table class="table__padded" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
        <tr><td align="center">
          <!-- Discount Card -->
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background: linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%); border-radius: 12px; padding: 32px; margin-bottom: 24px; border: 2px solid #22c55e;">
            <tr><td align="center">
              <p style="font-size: 48px; font-weight: 900; color: #15803d; margin: 0;">{discount_amount}</p>
              <p style="color: #6b7280; font-size: 14px; margin: 8px 0 0;">off your first order</p>
            </td></tr>
          </table>
          
          <!-- Code Box -->
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background: #1f2937; border-radius: 12px; padding: 20px; margin: 24px 0;">
            <tr><td align="center">
              <p style="color: #22c55e; font-size: 28px; font-weight: 800; letter-spacing: 4px; font-family: monospace; margin: 0;">{promo_code}</p>
              <p style="color: #9ca3af; font-size: 13px; margin: 12px 0 0;">Valid for first order only</p>
            </td></tr>
          </table>
          
          <p style="color: #4b5563; font-size: 15px; line-height: 1.6; margin: 24px 0;">Start your Fudgo journey with a treat on us! Thousands of restaurants are waiting.</p>
          
          <a href="#" class="btn-primary" style="padding: 16px 40px; font-size: 16px;">Claim Your Gift 🎉</a>
        </td></tr>
      </table>
    </td></tr>
  </table>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr><td style="height: 24px;"></td></tr>
  </table>"""
        
        footer = cls._footer(f"Welcome aboard, {user_name}! 💚")
        
        html = cls._base_template(
            header + body + footer,
            f"Get {discount_amount} OFF your first order with code {promo_code}"
        )
        
        plain = f"""🎁 Welcome Gift for {user_name}!

Get {discount_amount} OFF your first order!

PROMO CODE: {promo_code}
Valid for first order only.

Start ordering at fudgo.com!

© {cls._get_year()} Fudgo"""

        return {"subject": f"🎁 Your Welcome Gift: {discount_amount} OFF!", "html": html, "plain": plain}

    # ============================================================
    # DRIVER ASSIGNED - Map/tracking themed
    # ============================================================
    @classmethod
    def delivery_driver_assigned(
        cls, user_name: str, order_id: str,
        driver_name: str, estimated_time: str
    ) -> Dict[str, str]:
        """Driver assigned - tracking/map style with dark mode"""
        
        header = cls._header(
            f"Driver On The Way! 🛵",
            f"Order #{order_id}",
            "🛵"
        )
        
        body = f"""
  <table style="max-width:600px; margin: 0 auto;" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr><td class="body__details body__background" style="border-radius: 16px; padding: 24px;">
      <table class="table__padded" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
        <tr><td align="center">
          <!-- Driver Card -->
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background: linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%); border-radius: 12px; padding: 24px; margin-bottom: 24px;">
            <tr><td align="center">
              <div style="width: 64px; height: 64px; background: #22c55e; border-radius: 50%; display: inline-block; line-height: 64px; font-size: 28px;">👤</div>
              <p style="color: #1f2937; font-size: 18px; font-weight: 700; margin: 12px 0 4px;">{driver_name}</p>
              <p style="color: #6b7280; font-size: 13px; margin: 0;">Your Delivery Partner</p>
            </td></tr>
          </table>
          
          <!-- Info Rows -->
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background: #f9fafb; border-radius: 8px; padding: 16px; margin-bottom: 12px;">
            <tr>
              <td style="color: #6b7280; font-size: 14px;">📦 Order ID</td>
              <td align="right" style="color: #1f2937; font-size: 14px; font-weight: 600;">#{order_id}</td>
            </tr>
          </table>
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background: #f9fafb; border-radius: 8px; padding: 16px; margin-bottom: 24px;">
            <tr>
              <td style="color: #6b7280; font-size: 14px;">⏱️ Arriving In</td>
              <td align="right" style="color: #1f2937; font-size: 14px; font-weight: 600;">{estimated_time}</td>
            </tr>
          </table>
          
          <a href="#" class="btn-primary">Track Live Location 📍</a>
        </td></tr>
      </table>
    </td></tr>
  </table>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr><td style="height: 24px;"></td></tr>
  </table>"""
        
        footer = cls._footer()
        
        html = cls._base_template(
            header + body + footer,
            f"{driver_name} is delivering your order - arriving in {estimated_time}"
        )
        
        plain = f"""🛵 Driver On The Way!

Order #{order_id}

Your driver {driver_name} has picked up your order!
Arriving in: {estimated_time}

Track in the Fudgo app.

© {cls._get_year()} Fudgo"""

        return {"subject": f"🛵 {driver_name} is Delivering Your Order!", "html": html, "plain": plain}

    # ============================================================
    # ARRIVING SOON - Countdown/urgent style
    # ============================================================
    @classmethod
    def delivery_arriving_soon(cls, user_name: str, order_id: str, minutes_away: int = 5) -> Dict[str, str]:
        """Arriving soon - countdown timer style with dark mode"""
        
        header = cls._header(
            f"Almost There! 🏃",
            "Your order is just around the corner!",
            "🏃"
        )
        
        body = f"""
  <table style="max-width:600px; margin: 0 auto;" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr><td class="body__details body__background" style="border-radius: 16px; padding: 24px;">
      <table class="table__padded" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
        <tr><td align="center">
          <!-- Countdown Box -->
          <table role="presentation" cellpadding="0" cellspacing="0" border="0" style="background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%); border-radius: 16px; padding: 32px 48px; margin: 16px 0; border: 3px solid #f59e0b;">
            <tr><td align="center">
              <p style="font-size: 72px; font-weight: 900; color: #d97706; margin: 0; line-height: 1;">{minutes_away}<span style="font-size: 24px;">min</span></p>
            </td></tr>
          </table>
          
          <p style="color: #4b5563; font-size: 16px; line-height: 1.6; margin: 24px 0;">Please be ready to receive your order!</p>
          
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background: #f9fafb; border-radius: 8px; padding: 12px; margin-bottom: 24px;">
            <tr><td align="center">
              <p style="color: #6b7280; font-size: 14px; margin: 0;">Order #{order_id}</p>
            </td></tr>
          </table>
        </td></tr>
      </table>
    </td></tr>
  </table>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr><td style="height: 24px;"></td></tr>
  </table>
  
  <table style="max-width:600px; margin: 0 auto;" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr><td style="background: #fef3c7; border-radius: 12px; padding: 16px; text-align: center;">
      <p style="color: #92400e; font-size: 13px; font-weight: 500; margin: 0;">📱 Keep your phone nearby!</p>
    </td></tr>
  </table>
  
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr><td style="height: 24px;"></td></tr>
  </table>"""
        
        footer = cls._footer()
        
        html = cls._base_template(
            header + body + footer,
            f"Your order arrives in {minutes_away} minutes!"
        )
        
        plain = f"""🏃 Almost There!

Your order will arrive in {minutes_away} minutes!

Order #{order_id}

Please be ready to receive your order.

© {cls._get_year()} Fudgo"""

        return {"subject": f"🏃 {minutes_away} Min Away – Get Ready!", "html": html, "plain": plain}

    # ============================================================
    # ACCOUNT DEACTIVATED - Subtle, respectful goodbye
    # ============================================================
    @classmethod
    def account_deactivated(cls, user_name: str) -> Dict[str, str]:
        """Account deactivated - gentle farewell design with dark mode"""
        
        header = cls._header(
            f"We'll Miss You, {user_name} 👋",
            "Your Fudgo account has been deactivated as requested.",
            "👋"
        )
        
        body = f"""
  <table style="max-width:600px; margin: 0 auto;" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr><td class="body__details body__background" style="border-radius: 16px; padding: 24px;">
      <table class="table__padded" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
        <tr><td>
          <p style="color: #4b5563; font-size: 15px; line-height: 1.7; margin: 0 0 24px;">We're sad to see you go, but we understand.</p>
          
          <!-- Info Box -->
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background: #f0fdf4; border-radius: 12px; padding: 20px; margin: 24px 0;">
            <tr><td>
              <p style="color: #1f2937; font-size: 14px; font-weight: 600; margin: 0 0 8px;">💡 Changed Your Mind?</p>
              <p style="color: #6b7280; font-size: 14px; margin: 0; line-height: 1.5;">You can reactivate your account within 30 days by simply logging in. All your data will be restored.</p>
            </td></tr>
          </table>
          
          <p style="color: #4b5563; font-size: 15px; line-height: 1.7; margin: 24px 0;">If there's anything we could have done better, we'd love to hear from you.</p>
          
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin: 28px 0;">
            <tr>
              <td align="center">
                <a href="#" class="btn-primary" style="margin-right: 12px;">Reactivate Account</a>
                <a href="#" style="display: inline-block; border: 2px solid #e5e7eb; color: #6b7280; text-decoration: none; padding: 12px 24px; border-radius: 8px; font-weight: 500;">Give Feedback</a>
              </td>
            </tr>
          </table>
        </td></tr>
      </table>
    </td></tr>
  </table>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr><td style="height: 24px;"></td></tr>
  </table>"""
        
        footer = cls._footer("Thank you for being part of Fudgo 💚")
        
        html = cls._base_template(
            header + body + footer,
            "Your Fudgo account has been deactivated"
        )
        
        plain = f"""We'll Miss You, {user_name}

Your Fudgo account has been deactivated.

Changed your mind? Log in within 30 days to reactivate.

Thank you for being part of Fudgo!

© {cls._get_year()} Fudgo"""

        return {"subject": "👋 Account Deactivated – Fudgo", "html": html, "plain": plain}


# ============================================================
# CONVENIENCE FUNCTION
# ============================================================
def get_email_template(template_type: str, **kwargs) -> Dict[str, Any]:
    """Get email template by type"""
    templates = {
        # Auth
        "email_verification": EmailTemplates.email_verification,
        "resend_verification": EmailTemplates.resend_verification,
        "password_reset": EmailTemplates.password_reset,
        "password_reset_success": EmailTemplates.password_reset_success,
        "welcome_verified": EmailTemplates.welcome_verified,
        # Orders
        "order_confirmation": EmailTemplates.order_confirmation,
        "order_status_update": EmailTemplates.order_status_update,
        "order_delivered": EmailTemplates.order_delivered,
        # Promos
        "promotion_discount": EmailTemplates.promotion_discount,
        "welcome_promo": EmailTemplates.welcome_promo,
        # Delivery
        "delivery_driver_assigned": EmailTemplates.delivery_driver_assigned,
        "delivery_arriving_soon": EmailTemplates.delivery_arriving_soon,
        # Account
        "account_deactivated": EmailTemplates.account_deactivated,
    }
    template_func = templates.get(template_type)
    if not template_func:
        raise ValueError(f"Unknown template type: {template_type}")
    return template_func(**kwargs)
