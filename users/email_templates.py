# users/email_templates.py
"""
Modern Email Templates for Fudgo Food Delivery
Each template has a unique design matching its purpose
"""

from typing import Any, Dict
from django.conf import settings


class EmailTemplates:
    """Unique purpose-driven email templates for Fudgo"""

    @staticmethod
    def _get_year() -> int:
        from datetime import datetime
        return datetime.now().year

    @staticmethod
    def _get_company_name() -> str:
        return getattr(settings, "COMPANY_NAME", "Fudgo")

    # ============================================================
    # VERIFICATION EMAIL - Clean, trustworthy, focus on the code
    # ============================================================
    @classmethod
    def email_verification(cls, user_name: str, verification_code: str) -> Dict[str, str]:
        """Email verification - minimal, code-focused design"""
        
        html = f"""
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f0fdf4; margin: 0; padding: 40px 20px; }}
.container {{ max-width: 480px; margin: 0 auto; background: #fff; border-radius: 4px; overflow: hidden; box-shadow: 0 20px 40px rgba(34, 197, 94, 0.15); }}
.header {{ background: #22c55e; padding: 40px; text-align: center; }}
.header h1 {{ color: #fff; margin: 0; font-size: 28px; font-weight: 700; }}
.header p {{ color: rgba(255,255,255,0.9); margin: 8px 0 0; font-size: 14px; }}
.body {{ padding: 40px; text-align: center; }}
.greeting {{ font-size: 20px; color: #1f2937; margin-bottom: 16px; }}
.message {{ color: #6b7280; font-size: 15px; line-height: 1.6; margin-bottom: 32px; }}
.code-box {{ background: linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%); border: 3px dashed #22c55e; border-radius: 4px; padding: 32px; margin: 24px 0; }}
.code-label {{ font-size: 11px; color: #16a34a; text-transform: uppercase; letter-spacing: 2px; margin-bottom: 12px; font-weight: 600; }}
.code {{ font-size: 42px; font-weight: 800; color: #15803d; letter-spacing: 10px; font-family: 'Courier New', monospace; }}
.expires {{ background: #fef3c7; color: #92400e; padding: 12px 20px; border-radius: 4px; font-size: 13px; display: inline-block; margin-top: 24px; }}
.footer {{ background: #f9fafb; padding: 24px; text-align: center; border-top: 1px solid #e5e7eb; }}
.footer p {{ color: #9ca3af; font-size: 12px; margin: 4px 0; }}
.ignore {{ color: #9ca3af; font-size: 13px; margin-top: 24px; padding-top: 24px; border-top: 1px solid #e5e7eb; }}
</style></head>
<body><div class="container">
<div class="header"><h1>🍔 Fudgo</h1><p>Verify Your Email</p></div>
<div class="body">
<p class="greeting">Hey {user_name}! 👋</p>
<p class="message">Welcome to Fudgo! Enter this code to verify your email and start ordering delicious food.</p>
<div class="code-box">
<div class="code-label">Verification Code</div>
<div class="code">{verification_code}</div>
</div>
<div class="expires">⏱️ Expires in 30 minutes</div>
<p class="ignore">Didn't create an account? Just ignore this email.</p>
</div>
<div class="footer"><p>© {cls._get_year()} Fudgo. All rights reserved.</p></div>
</div></body></html>
"""
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
        """Resend verification - refresh/retry themed"""
        
        html = f"""
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #ecfdf5; margin: 0; padding: 40px 20px; }}
.container {{ max-width: 480px; margin: 0 auto; background: #fff; border-radius: 4px; overflow: hidden; box-shadow: 0 10px 30px rgba(0,0,0,0.1); }}
.header {{ background: linear-gradient(135deg, #10b981 0%, #059669 100%); padding: 36px; text-align: center; }}
.refresh-icon {{ font-size: 48px; margin-bottom: 12px; }}
.header h1 {{ color: #fff; margin: 0; font-size: 22px; font-weight: 600; }}
.body {{ padding: 36px; text-align: center; }}
.message {{ color: #4b5563; font-size: 15px; line-height: 1.7; margin-bottom: 28px; }}
.code-container {{ background: #f0fdf4; border-radius: 4px; padding: 28px; margin: 20px 0; }}
.new-badge {{ background: #22c55e; color: #fff; font-size: 10px; padding: 4px 10px; border-radius: 4px; text-transform: uppercase; letter-spacing: 1px; display: inline-block; margin-bottom: 16px; }}
.code {{ font-size: 38px; font-weight: 800; color: #059669; letter-spacing: 8px; font-family: monospace; }}
.timer {{ color: #6b7280; font-size: 13px; margin-top: 20px; }}
.timer strong {{ color: #dc2626; }}
.footer {{ padding: 20px; text-align: center; background: #f9fafb; }}
.footer p {{ color: #9ca3af; font-size: 12px; margin: 0; }}
</style></head>
<body><div class="container">
<div class="header">
<div class="refresh-icon">🔄</div>
<h1>New Verification Code</h1>
</div>
<div class="body">
<p class="message">No worries, <strong>{user_name}</strong>! Here's a fresh new code for you.</p>
<div class="code-container">
<span class="new-badge">✨ Fresh Code</span>
<div class="code">{verification_code}</div>
</div>
<p class="timer">Valid for <strong>30 minutes</strong></p>
</div>
<div class="footer"><p>© {cls._get_year()} Fudgo</p></div>
</div></body></html>
"""
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
        """Password reset - security-themed with lock icon"""
        
        html = f"""
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #fef2f2; margin: 0; padding: 40px 20px; }}
.container {{ max-width: 480px; margin: 0 auto; background: #fff; border-radius: 4px; overflow: hidden; box-shadow: 0 10px 30px rgba(0,0,0,0.1); border-top: 4px solid #ef4444; }}
.header {{ padding: 40px; text-align: center; background: linear-gradient(180deg, #fef2f2 0%, #fff 100%); }}
.lock-icon {{ width: 80px; height: 80px; background: linear-gradient(135deg, #fca5a5 0%, #f87171 100%); border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 20px; font-size: 36px; }}
.header h1 {{ color: #1f2937; margin: 0; font-size: 24px; font-weight: 700; }}
.header p {{ color: #6b7280; margin: 8px 0 0; font-size: 14px; }}
.body {{ padding: 0 36px 36px; }}
.message {{ color: #4b5563; font-size: 15px; line-height: 1.7; text-align: center; }}
.code-box {{ background: #1f2937; border-radius: 4px; padding: 28px; margin: 28px 0; text-align: center; }}
.code-label {{ color: #9ca3af; font-size: 11px; text-transform: uppercase; letter-spacing: 2px; margin-bottom: 12px; }}
.code {{ color: #fff; font-size: 36px; font-weight: 800; letter-spacing: 8px; font-family: monospace; }}
.warning {{ background: #fef3c7; border-left: 4px solid #f59e0b; padding: 16px; border-radius: 0 8px 8px 0; margin: 24px 0; }}
.warning p {{ color: #92400e; font-size: 13px; margin: 0; line-height: 1.5; }}
.warning strong {{ display: block; margin-bottom: 4px; }}
.expires {{ text-align: center; color: #dc2626; font-size: 14px; font-weight: 600; }}
.footer {{ padding: 20px; text-align: center; background: #f9fafb; border-top: 1px solid #e5e7eb; }}
.footer p {{ color: #9ca3af; font-size: 12px; margin: 0; }}
</style></head>
<body><div class="container">
<div class="header">
<div class="lock-icon">🔐</div>
<h1>Password Reset</h1>
<p>We received a reset request for your account</p>
</div>
<div class="body">
<p class="message">Hi <strong>{user_name}</strong>, use this code to reset your password.</p>
<div class="code-box">
<div class="code-label">Reset Code</div>
<div class="code">{reset_code}</div>
</div>
<p class="expires">⏱️ Expires in 15 minutes</p>
<div class="warning">
<p><strong>⚠️ Didn't request this?</strong>
If you didn't request a password reset, ignore this email. Your password won't change.</p>
</div>
</div>
<div class="footer"><p>© {cls._get_year()} Fudgo • Security Team</p></div>
</div></body></html>
"""
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
        """Password reset success - confirmation with shield"""
        
        html = f"""
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f0fdf4; margin: 0; padding: 40px 20px; }}
.container {{ max-width: 480px; margin: 0 auto; background: #fff; border-radius: 4px; overflow: hidden; box-shadow: 0 10px 30px rgba(34,197,94,0.15); }}
.header {{ background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%); padding: 48px; text-align: center; }}
.check-circle {{ width: 80px; height: 80px; background: rgba(255,255,255,0.2); border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 20px; font-size: 40px; }}
.header h1 {{ color: #fff; margin: 0; font-size: 24px; font-weight: 700; }}
.body {{ padding: 36px; text-align: center; }}
.message {{ color: #4b5563; font-size: 15px; line-height: 1.7; margin-bottom: 28px; }}
.success-box {{ background: #f0fdf4; border: 2px solid #22c55e; border-radius: 4px; padding: 20px; margin: 20px 0; }}
.success-box p {{ color: #166534; font-size: 14px; margin: 0; }}
.tips {{ text-align: left; background: #f9fafb; border-radius: 4px; padding: 20px; margin: 24px 0; }}
.tips h3 {{ color: #1f2937; font-size: 14px; margin: 0 0 12px; }}
.tip {{ display: flex; align-items: center; padding: 8px 0; color: #4b5563; font-size: 13px; }}
.tip span {{ margin-right: 10px; }}
.btn {{ display: inline-block; background: #22c55e; color: #fff; text-decoration: none; padding: 14px 32px; border-radius: 4px; font-weight: 600; margin-top: 20px; }}
.footer {{ padding: 20px; text-align: center; background: #f9fafb; }}
.footer p {{ color: #9ca3af; font-size: 12px; margin: 0; }}
</style></head>
<body><div class="container">
<div class="header">
<div class="check-circle">✅</div>
<h1>Password Updated!</h1>
</div>
<div class="body">
<p class="message">Great news, <strong>{user_name}</strong>! Your password has been successfully changed.</p>
<div class="success-box">
<p>🎉 You can now log in with your new password</p>
</div>
<div class="tips">
<h3>🛡️ Security Tips</h3>
<div class="tip"><span>📱</span> Enable two-factor authentication</div>
<div class="tip"><span>🔑</span> Use a unique password</div>
<div class="tip"><span>👀</span> Check your recent activity</div>
</div>
<a href="#" class="btn">Open Fudgo App</a>
</div>
<div class="footer"><p>© {cls._get_year()} Fudgo</p></div>
</div></body></html>
"""
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
        """Welcome email - party/celebration theme"""
        
        html = f"""
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: linear-gradient(135deg, #fef3c7 0%, #dcfce7 100%); margin: 0; padding: 40px 20px; }}
.container {{ max-width: 520px; margin: 0 auto; background: #fff; border-radius: 4px; overflow: hidden; box-shadow: 0 20px 50px rgba(0,0,0,0.15); }}
.header {{ background: linear-gradient(135deg, #22c55e 0%, #10b981 50%, #06b6d4 100%); padding: 48px 32px; text-align: center; position: relative; }}
.confetti {{ position: absolute; top: 0; left: 0; right: 0; bottom: 0; background: url('data:image/svg+xml,...') repeat; opacity: 0.1; }}
.party {{ font-size: 64px; margin-bottom: 16px; }}
.header h1 {{ color: #fff; margin: 0; font-size: 32px; font-weight: 800; }}
.header p {{ color: rgba(255,255,255,0.9); margin: 8px 0 0; font-size: 16px; }}
.body {{ padding: 40px 32px; }}
.user-card {{ background: linear-gradient(135deg, #f0fdf4 0%, #ecfdf5 100%); border-radius: 4px; padding: 24px; text-align: center; margin-bottom: 32px; border: 2px solid #22c55e; }}
.avatar {{ width: 64px; height: 64px; background: #22c55e; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 12px; font-size: 28px; color: #fff; font-weight: 700; }}
.username {{ color: #16a34a; font-size: 18px; font-weight: 700; }}
.verified {{ color: #6b7280; font-size: 13px; margin-top: 4px; }}
.features {{ margin: 32px 0; }}
.feature {{ display: flex; align-items: center; padding: 16px; background: #f9fafb; border-radius: 4px; margin-bottom: 12px; }}
.feature-icon {{ font-size: 28px; margin-right: 16px; }}
.feature-text h4 {{ color: #1f2937; font-size: 15px; margin: 0; font-weight: 600; }}
.feature-text p {{ color: #6b7280; font-size: 13px; margin: 4px 0 0; }}
.cta {{ text-align: center; margin: 32px 0; }}
.btn {{ display: inline-block; background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%); color: #fff; text-decoration: none; padding: 16px 40px; border-radius: 4px; font-weight: 700; font-size: 16px; box-shadow: 0 4px 15px rgba(34,197,94,0.4); }}
.footer {{ background: #1f2937; padding: 28px; text-align: center; }}
.footer-logo {{ color: #22c55e; font-size: 20px; font-weight: 700; margin-bottom: 8px; }}
.footer p {{ color: #9ca3af; font-size: 12px; margin: 4px 0; }}
</style></head>
<body><div class="container">
<div class="header">
<div class="party">🎉</div>
<h1>Welcome to Fudgo!</h1>
<p>Your email is verified – let's eat!</p>
</div>
<div class="body">
<div class="user-card">
<div class="avatar">{user_name[0].upper()}</div>
<div class="username">@{username}</div>
<div class="verified">✓ Verified Account</div>
</div>
<div class="features">
<div class="feature">
<span class="feature-icon">🍕</span>
<div class="feature-text"><h4>Thousands of Restaurants</h4><p>From local gems to your favorites</p></div>
</div>
<div class="feature">
<span class="feature-icon">⚡</span>
<div class="feature-text"><h4>Lightning Fast Delivery</h4><p>Hot food at your door, quick</p></div>
</div>
<div class="feature">
<span class="feature-icon">🎁</span>
<div class="feature-text"><h4>Exclusive Deals</h4><p>Members-only discounts daily</p></div>
</div>
<div class="feature">
<span class="feature-icon">📍</span>
<div class="feature-text"><h4>Real-time Tracking</h4><p>Watch your food come to you</p></div>
</div>
</div>
<div class="cta">
<a href="#" class="btn">Start Ordering Now 🚀</a>
</div>
</div>
<div class="footer">
<div class="footer-logo">🍔 Fudgo</div>
<p>© {cls._get_year()} Fudgo • Made with 💚 for food lovers</p>
</div>
</div></body></html>
"""
        plain = f"""🎉 Welcome to Fudgo, {user_name}!

Your email is verified! Username: @{username}

What you can do now:
🍕 Browse thousands of restaurants
⚡ Get lightning fast delivery
🎁 Access exclusive deals
📍 Track your orders in real-time

Start ordering at fudgo.com

© {cls._get_year()} Fudgo"""

        return {"subject": "🎉 Welcome to Fudgo, {user_name}!", "html": html, "plain": plain}

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
        """Order confirmation - receipt/invoice style with product images"""
        
        items_html = ""
        items_text = ""
        for item in items:
            image_url = item.get('image_url', '')
            image_html = f'<img src="{image_url}" alt="{item.get("name", "")}" style="width: 60px; height: 60px; border-radius: 4px; object-fit: cover; margin-right: 12px;">' if image_url else '<div style="width: 60px; height: 60px; border-radius: 4px; background: #f3f4f6; margin-right: 12px; display: flex; align-items: center; justify-content: center; font-size: 24px;">🍽️</div>'
            
            items_html += f"""
            <tr>
                <td style="padding: 16px 0; border-bottom: 1px solid #e5e7eb;">
                    <div style="display: flex; align-items: center;">
                        {image_html}
                        <div>
                            <div style="color: #1f2937; font-weight: 600; font-size: 15px;">{item.get('name', '')}</div>
                            <div style="color: #6b7280; font-size: 13px; margin-top: 2px;">Qty: {item.get('quantity', 1)}</div>
                        </div>
                    </div>
                </td>
                <td style="padding: 16px 0; border-bottom: 1px solid #e5e7eb; text-align: right; color: #1f2937; font-weight: 600; vertical-align: middle;">{item.get('price', '')}</td>
            </tr>"""
            items_text += f"  {item.get('name', '')} × {item.get('quantity', 1)} - {item.get('price', '')}\n"

        html = f"""
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f3f4f6; margin: 0; padding: 40px 20px; }}
.container {{ max-width: 560px; margin: 0 auto; background: #fff; border-radius: 4px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.08); }}
.header {{ background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%); padding: 32px; text-align: center; }}
.check {{ width: 64px; height: 64px; background: rgba(255,255,255,0.2); border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 16px; font-size: 32px; }}
.header h1 {{ color: #fff; margin: 0; font-size: 24px; font-weight: 700; }}
.order-id {{ color: rgba(255,255,255,0.9); font-size: 14px; margin-top: 8px; }}
.restaurant-badge {{ background: rgba(255,255,255,0.15); padding: 8px 16px; border-radius: 4px; display: inline-block; margin-top: 12px; color: #fff; font-size: 13px; }}
.body {{ padding: 32px; }}
.section {{ margin-bottom: 28px; }}
.section-title {{ color: #6b7280; font-size: 12px; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 16px; font-weight: 600; }}
.eta-box {{ background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%); border-radius: 4px; padding: 20px; text-align: center; margin-bottom: 28px; }}
.eta-label {{ color: #92400e; font-size: 12px; text-transform: uppercase; letter-spacing: 1px; }}
.eta-time {{ color: #78350f; font-size: 28px; font-weight: 800; margin-top: 4px; }}
.items-table {{ width: 100%; border-collapse: collapse; }}
.total-row {{ background: #f0fdf4; }}
.total-row td {{ padding: 16px; font-size: 18px; font-weight: 700; }}
.total-row td:first-child {{ color: #1f2937; }}
.total-row td:last-child {{ color: #22c55e; text-align: right; }}
.address {{ background: #f9fafb; border-radius: 4px; padding: 16px; }}
.address p {{ color: #4b5563; font-size: 14px; margin: 0; line-height: 1.5; }}
.btn {{ display: block; background: #22c55e; color: #fff; text-decoration: none; padding: 16px; border-radius: 4px; font-weight: 600; text-align: center; margin-top: 24px; }}
.footer {{ background: #f9fafb; padding: 24px; text-align: center; border-top: 1px solid #e5e7eb; }}
.footer p {{ color: #9ca3af; font-size: 12px; margin: 0; }}
</style></head>
<body><div class="container">
<div class="header">
<div class="check">✓</div>
<h1>Order Confirmed!</h1>
<p class="order-id">Order #{order_id}</p>
{"<div class='restaurant-badge'>🏪 " + restaurant_name + "</div>" if restaurant_name else ""}
</div>
<div class="body">
<div class="eta-box">
<div class="eta-label">Estimated Delivery</div>
<div class="eta-time">🕐 {estimated_time}</div>
</div>
<div class="section">
<div class="section-title">📦 Your Order</div>
<table class="items-table">
{items_html}
</table>
<div style="margin-top: 16px; padding-top: 16px; border-top: 1px dashed #e5e7eb;">
<table class="items-table">
<tr><td style="padding: 8px 0; color: #6b7280;">Subtotal</td><td style="padding: 8px 0; text-align: right; color: #6b7280;">{subtotal}</td></tr>
<tr><td style="padding: 8px 0; color: #6b7280;">Delivery Fee</td><td style="padding: 8px 0; text-align: right; color: #6b7280;">{delivery_fee}</td></tr>
</table>
</div>
<table class="items-table" style="margin-top: 12px;"><tr class="total-row"><td>Total</td><td>{total}</td></tr></table>
</div>
<div class="section">
<div class="section-title">📍 Delivery Address</div>
<div class="address"><p>{delivery_address}</p></div>
</div>
<a href="#" class="btn">Track Your Order 📍</a>
</div>
<div class="footer">
<p>Thank you for ordering, {user_name}!</p>
<p style="margin-top: 8px;">© {cls._get_year()} Fudgo</p>
</div>
</div></body></html>
"""
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
        """Order status - progress tracker design"""
        
        statuses = {
            "confirmed": {"icon": "✓", "color": "#22c55e", "bg": "#dcfce7", "step": 1},
            "preparing": {"icon": "👨‍🍳", "color": "#f59e0b", "bg": "#fef3c7", "step": 2},
            "picked_up": {"icon": "📦", "color": "#3b82f6", "bg": "#dbeafe", "step": 3},
            "on_the_way": {"icon": "🚗", "color": "#8b5cf6", "bg": "#ede9fe", "step": 3},
            "delivered": {"icon": "🎉", "color": "#22c55e", "bg": "#dcfce7", "step": 4},
        }
        s = statuses.get(status.lower(), statuses["confirmed"])
        
        def step_style(step_num):
            if step_num < s["step"]:
                return "background: #22c55e; color: #fff;"
            elif step_num == s["step"]:
                return f"background: {s['color']}; color: #fff; box-shadow: 0 0 0 4px {s['bg']};"
            else:
                return "background: #e5e7eb; color: #9ca3af;"

        eta_html = f'<div style="background: #f0fdf4; padding: 16px; border-radius: 4px; text-align: center; margin-top: 24px;"><span style="color: #166534; font-weight: 600;">⏱️ ETA: {estimated_time}</span></div>' if estimated_time else ""

        html = f"""
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f9fafb; margin: 0; padding: 40px 20px; }}
.container {{ max-width: 480px; margin: 0 auto; background: #fff; border-radius: 4px; overflow: hidden; box-shadow: 0 10px 30px rgba(0,0,0,0.08); }}
.header {{ background: {s['bg']}; padding: 40px; text-align: center; }}
.status-icon {{ font-size: 56px; margin-bottom: 16px; }}
.header h1 {{ color: {s['color']}; margin: 0; font-size: 22px; font-weight: 700; }}
.order-id {{ color: #6b7280; font-size: 14px; margin-top: 8px; }}
.body {{ padding: 32px; }}
.message {{ color: #4b5563; font-size: 15px; line-height: 1.6; text-align: center; margin-bottom: 32px; }}
.progress {{ display: flex; justify-content: space-between; align-items: center; padding: 0 20px; margin-bottom: 32px; }}
.step {{ width: 36px; height: 36px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 14px; font-weight: 700; }}
.line {{ flex: 1; height: 3px; background: #e5e7eb; margin: 0 8px; }}
.line.active {{ background: #22c55e; }}
.btn {{ display: block; background: {s['color']}; color: #fff; text-decoration: none; padding: 14px; border-radius: 4px; font-weight: 600; text-align: center; }}
.footer {{ padding: 20px; text-align: center; background: #f9fafb; }}
.footer p {{ color: #9ca3af; font-size: 12px; margin: 0; }}
</style></head>
<body><div class="container">
<div class="header">
<div class="status-icon">{s['icon']}</div>
<h1>{status.replace('_', ' ').title()}</h1>
<p class="order-id">Order #{order_id}</p>
</div>
<div class="body">
<p class="message">{status_message}</p>
<div class="progress">
<div class="step" style="{step_style(1)}">1</div>
<div class="line {'active' if s['step'] > 1 else ''}"></div>
<div class="step" style="{step_style(2)}">2</div>
<div class="line {'active' if s['step'] > 2 else ''}"></div>
<div class="step" style="{step_style(3)}">3</div>
<div class="line {'active' if s['step'] > 3 else ''}"></div>
<div class="step" style="{step_style(4)}">4</div>
</div>
{eta_html}
<a href="#" class="btn" style="margin-top: 24px;">Track Order 📍</a>
</div>
<div class="footer"><p>© {cls._get_year()} Fudgo</p></div>
</div></body></html>
"""
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
        """Order delivered - celebration with rating request and product images"""
        
        # Build items gallery if items provided
        items_gallery = ""
        if items:
            items_html = ""
            for item in items[:4]:  # Show max 4 items
                image_url = item.get('image_url', '')
                if image_url:
                    items_html += f'<div style="width: 80px; height: 80px; border-radius: 4px; overflow: hidden; border: 2px solid #fff; box-shadow: 0 2px 8px rgba(0,0,0,0.1);"><img src="{image_url}" alt="{item.get("name", "")}" style="width: 100%; height: 100%; object-fit: cover;"></div>'
                else:
                    items_html += f'<div style="width: 80px; height: 80px; border-radius: 4px; background: #f0fdf4; border: 2px solid #fff; box-shadow: 0 2px 8px rgba(0,0,0,0.1); display: flex; align-items: center; justify-content: center; font-size: 28px;">🍽️</div>'
            
            items_gallery = f'''
            <div style="margin: 24px 0;">
                <p style="color: #6b7280; font-size: 13px; margin-bottom: 12px;">Your order</p>
                <div style="display: flex; justify-content: center; gap: 8px; flex-wrap: wrap;">
                    {items_html}
                </div>
            </div>'''
        
        html = f"""
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: linear-gradient(135deg, #dcfce7 0%, #d1fae5 100%); margin: 0; padding: 40px 20px; }}
.container {{ max-width: 480px; margin: 0 auto; background: #fff; border-radius: 4px; overflow: hidden; box-shadow: 0 20px 40px rgba(34,197,94,0.2); }}
.header {{ background: linear-gradient(135deg, #22c55e 0%, #10b981 100%); padding: 48px; text-align: center; }}
.delivered-icon {{ font-size: 72px; margin-bottom: 16px; }}
.header h1 {{ color: #fff; margin: 0; font-size: 28px; font-weight: 800; }}
.header p {{ color: rgba(255,255,255,0.9); font-size: 15px; margin-top: 8px; }}
.body {{ padding: 40px 32px; text-align: center; }}
.restaurant {{ background: #f9fafb; border-radius: 4px; padding: 20px; margin-bottom: 24px; }}
.restaurant p {{ color: #6b7280; font-size: 13px; margin: 0 0 4px; }}
.restaurant h3 {{ color: #1f2937; font-size: 18px; margin: 0; font-weight: 600; }}
.rating-section {{ margin: 32px 0; }}
.rating-section h3 {{ color: #1f2937; font-size: 18px; margin-bottom: 16px; }}
.stars {{ font-size: 36px; letter-spacing: 8px; }}
.btn {{ display: inline-block; background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%); color: #fff; text-decoration: none; padding: 16px 40px; border-radius: 4px; font-weight: 700; font-size: 16px; box-shadow: 0 4px 15px rgba(245,158,11,0.4); }}
.reorder {{ display: block; color: #22c55e; text-decoration: none; font-weight: 600; margin-top: 20px; font-size: 15px; }}
.footer {{ background: #f9fafb; padding: 24px; text-align: center; }}
.footer p {{ color: #9ca3af; font-size: 12px; margin: 0; }}
</style></head>
<body><div class="container">
<div class="header">
<div class="delivered-icon">🍽️</div>
<h1>Enjoy Your Meal!</h1>
<p>Order #{order_id} delivered</p>
</div>
<div class="body">
<div class="restaurant">
<p>Delivered from</p>
<h3>🏪 {restaurant_name}</h3>
</div>
{items_gallery}
<div class="rating-section">
<h3>How was your food?</h3>
<div class="stars">⭐⭐⭐⭐⭐</div>
</div>
<a href="#" class="btn">Rate Your Order</a>
<a href="#" class="reorder">🔄 Order Again</a>
</div>
<div class="footer">
<p>Thanks for choosing Fudgo, {user_name}!</p>
<p style="margin-top: 8px;">© {cls._get_year()} Fudgo</p>
</div>
</div></body></html>
"""
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
    # PROMOTION DISCOUNT - Bold, attention-grabbing, urgent
    # ============================================================
    @classmethod
    def promotion_discount(
        cls, user_name: str, promo_code: str, discount_amount: str,
        description: str, expiry_date: str, min_order: str = None,
        featured_items: list = None, restaurant_name: str = None
    ) -> Dict[str, str]:
        """Promotion - bold sale/discount design with featured product images"""
        
        min_html = f'<p style="color: rgba(255,255,255,0.8); font-size: 13px; margin-top: 12px;">Min. order: {min_order}</p>' if min_order else ""
        min_text = f"\nMin. order: {min_order}" if min_order else ""
        
        # Featured items gallery
        items_gallery = ""
        if featured_items:
            items_html = ""
            for item in featured_items[:3]:  # Show max 3 featured items
                image_url = item.get('image_url', '')
                name = item.get('name', '')
                price = item.get('price', '')
                original_price = item.get('original_price', '')
                
                if image_url:
                    items_html += f'''
                    <div style="flex: 1; min-width: 140px; max-width: 160px; background: #fff; border-radius: 4px; overflow: hidden; box-shadow: 0 4px 12px rgba(0,0,0,0.1);">
                        <img src="{image_url}" alt="{name}" style="width: 100%; height: 100px; object-fit: cover;">
                        <div style="padding: 12px;">
                            <div style="font-size: 13px; font-weight: 600; color: #1f2937; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">{name}</div>
                            <div style="margin-top: 6px;">
                                {"<span style='text-decoration: line-through; color: #9ca3af; font-size: 12px; margin-right: 6px;'>" + original_price + "</span>" if original_price else ""}
                                <span style="color: #ef4444; font-weight: 700;">{price}</span>
                            </div>
                        </div>
                    </div>'''
            
            items_gallery = f'''
            <div style="margin: 28px 0;">
                <p style="color: #6b7280; font-size: 14px; font-weight: 600; margin-bottom: 16px;">🔥 Featured Deals</p>
                <div style="display: flex; gap: 12px; justify-content: center; flex-wrap: wrap;">
                    {items_html}
                </div>
            </div>'''
        
        restaurant_html = f'<div style="background: rgba(255,255,255,0.1); padding: 8px 16px; border-radius: 4px; display: inline-block; margin-top: 12px; color: #fff; font-size: 13px;">🏪 {restaurant_name}</div>' if restaurant_name else ""

        html = f"""
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #fef2f2; margin: 0; padding: 40px 20px; }}
.container {{ max-width: 520px; margin: 0 auto; background: #fff; border-radius: 4px; overflow: hidden; box-shadow: 0 20px 50px rgba(239,68,68,0.2); }}
.header {{ background: linear-gradient(135deg, #ef4444 0%, #dc2626 50%, #b91c1c 100%); padding: 48px 32px; text-align: center; position: relative; overflow: hidden; }}
.sale-badge {{ position: absolute; top: 20px; right: -30px; background: #fbbf24; color: #78350f; padding: 8px 40px; font-size: 12px; font-weight: 800; transform: rotate(45deg); text-transform: uppercase; }}
.discount {{ font-size: 64px; font-weight: 900; color: #fff; margin: 0; text-shadow: 2px 2px 0 rgba(0,0,0,0.1); }}
.discount-label {{ color: rgba(255,255,255,0.9); font-size: 18px; margin-top: 8px; }}
.body {{ padding: 32px; text-align: center; }}
.message {{ color: #4b5563; font-size: 16px; line-height: 1.6; margin-bottom: 24px; }}
.code-box {{ background: linear-gradient(135deg, #fef2f2 0%, #fee2e2 100%); border: 3px dashed #ef4444; border-radius: 4px; padding: 24px; margin: 24px 0; }}
.code-label {{ color: #dc2626; font-size: 12px; text-transform: uppercase; letter-spacing: 2px; margin-bottom: 8px; font-weight: 600; }}
.code {{ font-size: 32px; font-weight: 800; color: #b91c1c; letter-spacing: 4px; font-family: monospace; }}
.expires {{ background: #fef3c7; color: #92400e; padding: 12px 24px; border-radius: 4px; font-size: 14px; display: inline-block; margin: 20px 0; font-weight: 600; }}
.btn {{ display: block; background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%); color: #fff; text-decoration: none; padding: 18px; border-radius: 4px; font-weight: 700; font-size: 18px; box-shadow: 0 4px 15px rgba(239,68,68,0.4); }}
.footer {{ background: #1f2937; padding: 24px; text-align: center; }}
.footer p {{ color: #9ca3af; font-size: 12px; margin: 0; }}
</style></head>
<body><div class="container">
<div class="header">
<div class="sale-badge">Limited!</div>
<div class="discount">{discount_amount}</div>
<p class="discount-label">OFF Your Order!</p>
{min_html}
{restaurant_html}
</div>
<div class="body">
<p class="message">{description}</p>
{items_gallery}
<div class="code-box">
<div class="code-label">Your Promo Code</div>
<div class="code">{promo_code}</div>
</div>
<div class="expires">⏰ Expires: {expiry_date}</div>
<a href="#" class="btn">Use Code Now 🔥</a>
</div>
<div class="footer">
<p>Happy eating, {user_name}! 🍔</p>
<p style="margin-top: 8px;">© {cls._get_year()} Fudgo</p>
</div>
</div></body></html>
"""
        items_text = ""
        if featured_items:
            items_text = "\n\nFeatured items:\n" + "\n".join([f"  • {item.get('name', '')} - {item.get('price', '')}" for item in featured_items[:3]])
        
        plain = f"""🔥 {discount_amount} OFF!

{description}{items_text}

PROMO CODE: {promo_code}{min_text}

⏰ Expires: {expiry_date}

Use code at fudgo.com!

© {cls._get_year()} Fudgo"""

        return {"subject": f"🔥 {discount_amount} OFF – Limited Time!", "html": html, "plain": plain}

    # ============================================================
    # WELCOME PROMO - Gift themed, first order discount
    # ============================================================
    @classmethod
    def welcome_promo(cls, user_name: str, promo_code: str, discount_amount: str) -> Dict[str, str]:
        """Welcome promo - gift box themed"""
        
        html = f"""
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: linear-gradient(135deg, #fae8ff 0%, #e9d5ff 100%); margin: 0; padding: 40px 20px; }}
.container {{ max-width: 480px; margin: 0 auto; background: #fff; border-radius: 4px; overflow: hidden; box-shadow: 0 20px 50px rgba(168,85,247,0.2); }}
.header {{ background: linear-gradient(135deg, #a855f7 0%, #9333ea 50%, #7c3aed 100%); padding: 48px; text-align: center; }}
.gift {{ font-size: 80px; margin-bottom: 16px; }}
.header h1 {{ color: #fff; margin: 0; font-size: 28px; font-weight: 800; }}
.header p {{ color: rgba(255,255,255,0.9); font-size: 16px; margin-top: 8px; }}
.body {{ padding: 40px 32px; text-align: center; }}
.discount-card {{ background: linear-gradient(135deg, #f3e8ff 0%, #e9d5ff 100%); border-radius: 4px; padding: 32px; margin-bottom: 28px; border: 2px solid #a855f7; }}
.amount {{ font-size: 48px; font-weight: 900; color: #7c3aed; }}
.amount-label {{ color: #6b7280; font-size: 14px; margin-top: 8px; }}
.code-box {{ background: #1f2937; border-radius: 4px; padding: 20px; margin: 24px 0; }}
.code {{ color: #a855f7; font-size: 28px; font-weight: 800; letter-spacing: 4px; font-family: monospace; }}
.valid {{ color: #9ca3af; font-size: 13px; margin-top: 12px; }}
.message {{ color: #4b5563; font-size: 15px; line-height: 1.6; margin-bottom: 24px; }}
.btn {{ display: inline-block; background: linear-gradient(135deg, #a855f7 0%, #9333ea 100%); color: #fff; text-decoration: none; padding: 16px 40px; border-radius: 4px; font-weight: 700; font-size: 16px; box-shadow: 0 4px 15px rgba(168,85,247,0.4); }}
.footer {{ background: #f9fafb; padding: 24px; text-align: center; }}
.footer p {{ color: #9ca3af; font-size: 12px; margin: 0; }}
</style></head>
<body><div class="container">
<div class="header">
<div class="gift">🎁</div>
<h1>A Gift For You!</h1>
<p>Welcome to the Fudgo family</p>
</div>
<div class="body">
<div class="discount-card">
<div class="amount">{discount_amount}</div>
<div class="amount-label">off your first order</div>
</div>
<div class="code-box">
<div class="code">{promo_code}</div>
<p class="valid">Valid for first order only</p>
</div>
<p class="message">Start your Fudgo journey with a treat on us! Thousands of restaurants are waiting.</p>
<a href="#" class="btn">Claim Your Gift 🎉</a>
</div>
<div class="footer">
<p>Welcome aboard, {user_name}! 💜</p>
<p style="margin-top: 8px;">© {cls._get_year()} Fudgo</p>
</div>
</div></body></html>
"""
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
        """Driver assigned - tracking/map style"""
        
        html = f"""
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #eff6ff; margin: 0; padding: 40px 20px; }}
.container {{ max-width: 480px; margin: 0 auto; background: #fff; border-radius: 4px; overflow: hidden; box-shadow: 0 10px 30px rgba(59,130,246,0.15); }}
.header {{ background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%); padding: 40px; text-align: center; }}
.vehicle {{ font-size: 56px; margin-bottom: 12px; }}
.header h1 {{ color: #fff; margin: 0; font-size: 22px; font-weight: 700; }}
.header p {{ color: rgba(255,255,255,0.9); font-size: 14px; margin-top: 8px; }}
.body {{ padding: 32px; }}
.driver-card {{ background: linear-gradient(135deg, #eff6ff 0%, #dbeafe 100%); border-radius: 4px; padding: 24px; text-align: center; margin-bottom: 24px; }}
.driver-avatar {{ width: 64px; height: 64px; background: #3b82f6; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 12px; font-size: 28px; }}
.driver-name {{ color: #1f2937; font-size: 18px; font-weight: 700; }}
.driver-label {{ color: #6b7280; font-size: 13px; margin-top: 4px; }}
.info-row {{ display: flex; justify-content: space-between; padding: 16px; background: #f9fafb; border-radius: 4px; margin-bottom: 12px; }}
.info-row .label {{ color: #6b7280; font-size: 14px; }}
.info-row .value {{ color: #1f2937; font-size: 14px; font-weight: 600; }}
.btn {{ display: block; background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%); color: #fff; text-decoration: none; padding: 16px; border-radius: 4px; font-weight: 600; text-align: center; }}
.footer {{ padding: 20px; text-align: center; background: #f9fafb; }}
.footer p {{ color: #9ca3af; font-size: 12px; margin: 0; }}
</style></head>
<body><div class="container">
<div class="header">
<div class="vehicle">🛵</div>
<h1>Driver On The Way!</h1>
<p>Order #{order_id}</p>
</div>
<div class="body">
<div class="driver-card">
<div class="driver-avatar">👤</div>
<div class="driver-name">{driver_name}</div>
<div class="driver-label">Your Delivery Partner</div>
</div>
<div class="info-row">
<span class="label">📦 Order ID</span>
<span class="value">#{order_id}</span>
</div>
<div class="info-row">
<span class="label">⏱️ Arriving In</span>
<span class="value">{estimated_time}</span>
</div>
<a href="#" class="btn">Track Live Location 📍</a>
</div>
<div class="footer"><p>© {cls._get_year()} Fudgo</p></div>
</div></body></html>
"""
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
        """Arriving soon - countdown timer style"""
        
        html = f"""
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #fef3c7; margin: 0; padding: 40px 20px; }}
.container {{ max-width: 420px; margin: 0 auto; background: #fff; border-radius: 4px; overflow: hidden; box-shadow: 0 20px 40px rgba(245,158,11,0.25); border: 3px solid #f59e0b; }}
.header {{ background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%); padding: 48px 32px; text-align: center; }}
.alert {{ font-size: 64px; margin-bottom: 12px; animation: pulse 1s infinite; }}
@keyframes pulse {{ 0%, 100% {{ transform: scale(1); }} 50% {{ transform: scale(1.1); }} }}
.countdown {{ background: #fff; color: #d97706; font-size: 72px; font-weight: 900; padding: 20px 40px; border-radius: 4px; display: inline-block; margin: 16px 0; box-shadow: 0 4px 15px rgba(0,0,0,0.1); }}
.countdown span {{ font-size: 24px; }}
.header p {{ color: #fff; font-size: 18px; margin: 0; font-weight: 600; }}
.body {{ padding: 32px; text-align: center; }}
.message {{ color: #4b5563; font-size: 16px; line-height: 1.6; margin-bottom: 24px; }}
.order-id {{ color: #6b7280; font-size: 14px; background: #f9fafb; padding: 12px; border-radius: 4px; }}
.footer {{ background: #fffbeb; padding: 20px; text-align: center; }}
.footer p {{ color: #92400e; font-size: 13px; margin: 0; font-weight: 500; }}
</style></head>
<body><div class="container">
<div class="header">
<div class="alert">🏃</div>
<div class="countdown">{minutes_away}<span>min</span></div>
<p>Almost there!</p>
</div>
<div class="body">
<p class="message">Your order is just around the corner! Please be ready to receive it.</p>
<div class="order-id">Order #{order_id}</div>
</div>
<div class="footer">
<p>📱 Keep your phone nearby!</p>
</div>
</div></body></html>
"""
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
        """Account deactivated - gentle farewell design"""
        
        html = f"""
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f9fafb; margin: 0; padding: 40px 20px; }}
.container {{ max-width: 480px; margin: 0 auto; background: #fff; border-radius: 4px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.06); border: 1px solid #e5e7eb; }}
.header {{ padding: 40px; text-align: center; border-bottom: 1px solid #e5e7eb; }}
.wave {{ font-size: 48px; margin-bottom: 16px; }}
.header h1 {{ color: #1f2937; margin: 0; font-size: 22px; font-weight: 600; }}
.body {{ padding: 32px; }}
.message {{ color: #4b5563; font-size: 15px; line-height: 1.7; margin-bottom: 24px; }}
.info-box {{ background: #f9fafb; border-radius: 4px; padding: 20px; margin: 24px 0; }}
.info-box h4 {{ color: #1f2937; font-size: 14px; margin: 0 0 8px; }}
.info-box p {{ color: #6b7280; font-size: 14px; margin: 0; line-height: 1.5; }}
.btn {{ display: inline-block; background: #22c55e; color: #fff; text-decoration: none; padding: 14px 28px; border-radius: 4px; font-weight: 600; }}
.btn-outline {{ display: inline-block; border: 2px solid #e5e7eb; color: #6b7280; text-decoration: none; padding: 12px 24px; border-radius: 4px; font-weight: 500; margin-left: 12px; }}
.cta {{ text-align: center; margin: 28px 0; }}
.footer {{ background: #f9fafb; padding: 24px; text-align: center; border-top: 1px solid #e5e7eb; }}
.footer p {{ color: #9ca3af; font-size: 12px; margin: 0; }}
</style></head>
<body><div class="container">
<div class="header">
<div class="wave">👋</div>
<h1>We'll Miss You, {user_name}</h1>
</div>
<div class="body">
<p class="message">Your Fudgo account has been deactivated as requested. We're sad to see you go, but we understand.</p>
<div class="info-box">
<h4>💡 Changed Your Mind?</h4>
<p>You can reactivate your account within 30 days by simply logging in. All your data will be restored.</p>
</div>
<p class="message">If there's anything we could have done better, we'd love to hear from you.</p>
<div class="cta">
<a href="#" class="btn">Reactivate Account</a>
<a href="#" class="btn-outline">Give Feedback</a>
</div>
</div>
<div class="footer">
<p>Thank you for being part of Fudgo ��</p>
<p style="margin-top: 8px;">© {cls._get_year()} Fudgo</p>
</div>
</div></body></html>
"""
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
