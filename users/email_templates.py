# users/email_templates.py
"""
Modern Email Templates for Fudgo Food Delivery
Responsive light theme with orange-led food branding, accessible status colors, and email-safe tables
"""

from html import escape
from typing import Any, Dict
from urllib.parse import quote, urljoin, urlparse

from django.conf import settings


class EmailTemplates:
    """Professional transactional and promotional email templates for food delivery."""

    # ============================================================
    # SHARED EMAIL DESIGN SYSTEM
    # ============================================================

    BASE_STYLES = """
    * { box-sizing: border-box; }
    html, body { margin: 0 !important; padding: 0 !important; width: 100% !important; }
    body, table, td, a { -webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; }
    table { border-collapse: collapse; border-spacing: 0; mso-table-lspace: 0pt; mso-table-rspace: 0pt; }
    img { border: 0; display: block; line-height: 100%; outline: none; text-decoration: none; }
    .main { margin: 0; padding: 0; width: 100%; background-color: #FFF7F0; color: #29231F; font-family: Arial, Helvetica, sans-serif; font-size: 15px; line-height: 1.55; }
    .email-shell { width: 100%; max-width: 600px; }
    .header { max-width: 600px; background-color: #FFFFFF; border: 1px solid #F0E4DA; border-top: 5px solid #FF6B00; border-radius: 16px; }
    .header__inner-container { padding: 26px 28px 22px; margin: 0; }
    .header__title { padding: 18px 0 8px; color: #24170D; font-size: 27px; font-weight: 800; line-height: 1.2; letter-spacing: -0.45px; }
    .header__subtitle { padding: 0 0 4px; color: #625A54; font-size: 14px; line-height: 1.65; }
    .body__details { padding: 24px; }
    .body__background { background-color: #FFFFFF; color: #29231F; border: 1px solid #F0E4DA; border-radius: 14px; }
    .highlight { color: #3B1F6B; background-color: #F2EAF8; border: 1px solid #E8DCF2; padding: 4px 9px; border-radius: 7px; font-size: 12px; font-weight: 700; }
    .table__padded td { padding: 10px; }
    .table__padded td td { padding: 0; }
    .indent { background-color: #FFFFFF; }
    .label { color: inherit !important; text-decoration: none !important; }
    .label-details { color: #736B65 !important; text-decoration: none !important; }
    .product__promotion { background-color: #FF6B00; color: #24170D; font-size: 11px; padding: 3px 7px; border-radius: 5px; font-weight: 700; }
    .btn-primary { color: #24170D !important; background-color: #FF6B00 !important; border: 1px solid #FF6B00; padding: 13px 25px; font-size: 14px; line-height: 1.2; border-radius: 10px; font-weight: 700; text-decoration: none !important; display: inline-block; box-shadow: 0 5px 14px rgba(112, 53, 14, 0.18); }
    .footer { max-width: 600px; padding: 24px 20px; text-align: center; background-color: #302733; border-top: 4px solid #FF6B00; border-radius: 14px; }
    .footer p { color: #E7DED8; font-size: 12px; line-height: 1.6; margin: 5px 0; }
    .footer a { color: #FFD0A8 !important; }
    .email-motion-icon { display: inline-block; animation: email-float 2.8s ease-in-out infinite; transform-origin: center; }
    .email-step-active { animation: email-pulse 2s ease-in-out infinite; }
    .motion-enter { animation: email-enter 480ms ease-out both; }
    .food-item-cell { vertical-align: top; padding: 6px; }
    @keyframes email-float { 0%, 100% { transform: translateY(0); } 50% { transform: translateY(-3px); } }
    @keyframes email-pulse { 0%, 100% { box-shadow: 0 0 0 4px rgba(255,107,0,.15); } 50% { box-shadow: 0 0 0 7px rgba(255,107,0,.06); } }
    @keyframes email-enter { from { opacity: .55; transform: translateY(7px); } to { opacity: 1; transform: translateY(0); } }
    @media (prefers-reduced-motion: reduce) { .email-motion-icon, .email-step-active, .motion-enter { animation: none !important; transform: none !important; } }
    @media only screen and (max-width: 620px) {
      .header__inner-container { padding: 22px 18px 18px !important; }
      .header__title { font-size: 23px !important; }
      .body__details { padding: 18px !important; }
      .footer { padding: 20px 15px !important; }
      .food-item-cell { display: block !important; width: 100% !important; }
      .mobile-stack { display: block !important; width: 100% !important; }
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
    def _get_customer_app_url(cls, *parts: str) -> str:
        base_url = str(getattr(settings, "CUSTOMER_APP_URL", "https://fudgo.com") or "https://fudgo.com").rstrip("/")
        suffix = "/".join(quote(str(part).strip("/"), safe="") for part in parts if str(part).strip("/"))
        return f"{base_url}/{suffix}" if suffix else base_url

    @classmethod
    def _get_support_url(cls) -> str:
        reply_to = getattr(settings, "EMAIL_REPLY_TO", None) or getattr(settings, "DEFAULT_FROM_EMAIL", None)
        return f"mailto:{reply_to}" if reply_to else cls._get_customer_app_url()

    @classmethod
    def _base_template(cls, content: str, preheader: str = "") -> str:
        """Wrap email content in a responsive, light, email-client-safe shell."""
        safe_company = escape(str(cls._get_company_name()))
        safe_preheader = escape(str(preheader or ""))
        return f"""<!doctype html>
<html lang="en">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <meta name="x-apple-disable-message-reformatting" />
  <meta name="color-scheme" content="light" />
  <meta name="supported-color-schemes" content="light" />
  <title>{safe_company}</title>
  <style type="text/css">{cls.BASE_STYLES}</style>
</head>
<body class="main" style="margin:0;padding:0;background-color:#FFF7F0;color:#29231F;font-family:Arial,Helvetica,sans-serif;">
  <div style="display:none!important;visibility:hidden;opacity:0;color:transparent;height:0;width:0;max-height:0;max-width:0;overflow:hidden;mso-hide:all;">{safe_preheader}</div>
  <table class="main" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#FFF7F0" style="width:100%;background-color:#FFF7F0;">
    <tr><td align="center" style="padding:24px 12px;">
      <table class="email-shell" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="width:100%;max-width:600px;">
        <tr><td>{content}</td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>"""

    @classmethod
    def _header(cls, title: str, subtitle: str = "", icon: str = "🍔") -> str:
        """Generate the shared food-delivery brand header."""
        safe_icon = escape(str(icon))
        safe_company = escape(str(cls._get_company_name()))
        subtitle_html = f'<tr><td class="header__subtitle">{subtitle}</td></tr>' if subtitle else ""
        return f"""
<table style="max-width:600px;margin:0 auto 16px;" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
  <tr><td class="header" bgcolor="#FFFFFF" style="background-color:#FFFFFF;border:1px solid #F0E4DA;border-top:5px solid #FF6B00;border-radius:16px;">
    <table class="header__inner-container" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="padding:26px 28px 22px;">
      <tr>
        <td width="52" valign="middle" style="width:52px;">
          <table role="presentation" width="40" cellpadding="0" cellspacing="0" border="0"><tr><td align="center" valign="middle" width="40" height="40" bgcolor="#FF6B00" style="width:40px;height:40px;background-color:#FF6B00;border-radius:12px;font-size:21px;line-height:40px;">
            <span class="email-motion-icon">{safe_icon}</span>
          </td></tr></table>
        </td>
        <td valign="middle" style="padding-left:10px;">
          <p style="margin:0;color:#3B1F6B;font-size:18px;line-height:1.2;font-weight:800;">{safe_company}</p>
          <p style="margin:4px 0 0;color:#756B64;font-size:10px;line-height:1.2;letter-spacing:1.4px;text-transform:uppercase;">Food, made effortless</p>
        </td>
      </tr>
      <tr><td colspan="2" class="header__title" style="padding:18px 0 8px;color:#24170D;font-size:27px;font-weight:800;line-height:1.2;letter-spacing:-0.45px;">{title}</td></tr>
      {subtitle_html}
    </table>
  </td></tr>
  <tr><td height="14" style="height:14px;font-size:0;line-height:0;">&nbsp;</td></tr>
</table>"""

    @classmethod
    def _footer(cls, message: str = "") -> str:
        """Generate the quiet, consistent email footer."""
        safe_message = escape(str(message or ""))
        safe_company = escape(str(cls._get_company_name()))
        msg_html = f'<p style="color:#F4E8DF;margin:0 0 10px;">{safe_message}</p>' if safe_message else ""
        return f"""
<table style="max-width:600px;margin:16px auto 0;" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
  <tr><td class="footer" bgcolor="#302733" style="padding:24px 20px;text-align:center;background-color:#302733;border-top:4px solid #FF6B00;border-radius:14px;">
    {msg_html}
    <p style="font-size:17px;line-height:1.3;font-weight:800;color:#FFFFFF;margin:0 0 8px;">{safe_company}</p>
    <p style="color:#E7DED8;font-size:12px;margin:0;">© {cls._get_year()} {safe_company}. All rights reserved.</p>
    <p style="color:#CFC4BD;font-size:11px;margin:8px 0 0;">Thanks for choosing us for your next meal.</p>
  </td></tr>
</table>"""

    @classmethod
    def _dashed_separator(cls) -> str:
        """Generate a light, unobtrusive receipt separator."""
        return """
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
  <tr><td style="height:14px;font-size:0;line-height:0;">&nbsp;</td></tr>
  <tr><td style="border-top:1px dashed #E7D9CE;font-size:0;line-height:0;">&nbsp;</td></tr>
  <tr><td style="height:14px;font-size:0;line-height:0;">&nbsp;</td></tr>
</table>"""

    @classmethod
    def _code_box(cls, code: str, label: str = "Your Code") -> str:
        """Generate an accessible, high-contrast verification-code card."""
        safe_code = escape(str(code))
        safe_label = escape(str(label))
        return f"""
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin:20px 0;">
  <tr><td align="center">
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" bgcolor="#FFF3E8" style="background-color:#FFF3E8;border:2px solid #FF6B00;border-radius:14px;padding:20px 32px;">
      <tr><td align="center">
        <p style="color:#3B1F6B;font-size:11px;text-transform:uppercase;letter-spacing:1.8px;margin:0 0 10px;font-weight:700;">{safe_label}</p>
        <p style="font-size:34px;font-weight:800;color:#24170D;letter-spacing:7px;font-family:'Courier New',monospace;margin:0;">{safe_code}</p>
      </td></tr>
    </table>
  </td></tr>
</table>"""

    # ============================================================
    # VERIFICATION EMAIL - Clean, trustworthy, focus on the code
    # ============================================================
    @classmethod
    def email_verification(cls, user_name: str, verification_code: str) -> Dict[str, str]:
        """Email verification - minimal, code-focused design with responsive light styling"""
        
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
        """Resend verification - refresh/retry themed with responsive light styling"""
        
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
        """Password reset - security-themed with lock icon"""
        
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
        """Password reset success - confirmation with shield"""
        
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
          <table role="presentation" cellpadding="0" cellspacing="0" border="0" style="background: #FFF3E8; border: 2px solid #FF6B00; border-radius: 12px; padding: 20px 40px; margin: 16px 0;">
            <tr><td align="center">
              <p style="color: #3B1F6B; font-size: 16px; margin: 0;">🎉 You can now log in with your new password</p>
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
          
          <a href="{cls._get_customer_app_url()}" class="btn-primary" style="margin-top: 16px;">Open Fudgo App</a>
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
        """Welcome email - party/celebration theme with responsive light styling"""
        
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
          <table role="presentation" cellpadding="0" cellspacing="0" border="0" style="background: linear-gradient(135deg, #FFF3E8 0%, #FFF7F0 100%); border-radius: 12px; padding: 24px; text-align: center; margin-bottom: 24px; border: 2px solid #FF6B00; width: 100%;">
            <tr><td align="center">
              <div style="width: 64px; height: 64px; background: #FF6B00; border-radius: 50%; display: inline-block; line-height: 64px; font-size: 28px; color: #24170D; font-weight: 700;">{(user_name[:1] or 'F').upper()}</div>
              <p style="color: #C94F00; font-size: 18px; font-weight: 700; margin: 12px 0 4px;">@{username}</p>
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
          
          <a href="{cls._get_customer_app_url()}" class="btn-primary" style="margin-top: 16px; padding: 16px 40px; font-size: 16px;">Start Ordering Now 🚀</a>
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

Start ordering at {cls._get_customer_app_url()}

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
        """Order confirmation - responsive receipt with product images"""
        
        # Build items HTML
        items_html = ""
        items_text = ""
        for item in items:
            image_url = item.get('image_url', '')
            name = item.get('name', '')
            qty = item.get('quantity', 1)
            price = item.get('price', '')
            original_price = item.get('original_price', '')
            
            image_cell = f'<img src="{image_url}" alt="{name}" style="width: 60px; height: 60px; border-radius: 8px; object-fit: cover;">' if image_url else '<div style="width: 60px; height: 60px; border-radius: 8px; background: #FFF3E8; text-align: center; line-height: 60px; font-size: 24px;">🍽️</div>'
            
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
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background: linear-gradient(135deg, #FFF3E8 0%, #FFE2CC 100%); border-radius: 12px; padding: 20px; margin-bottom: 16px;">
        <tr><td align="center">
          <p style="color: #3B1F6B; font-size: 12px; text-transform: uppercase; letter-spacing: 1px; margin: 0;">Estimated Delivery</p>
          <p style="color: #3B1F6B; font-size: 28px; font-weight: 800; margin: 8px 0 0;">🕐 {estimated_time}</p>
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
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background: #FFF3E8; border-radius: 8px;">
        <tr>
          <td style="padding: 16px; font-size: 18px; font-weight: 700; color: #1f2937;">Total</td>
          <td align="right" style="padding: 16px; font-size: 18px; font-weight: 700; color: #3B1F6B;">{total}</td>
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
          <a href="{cls._get_customer_app_url()}" class="btn-primary">Open Fudgo App</a>
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
        """Order status - progress tracker with semantic delivery-status colors"""
        
        status_aliases = {
            "placed": "confirmed",
            "accepted": "confirmed",
            "ready": "preparing",
            "picked_up": "on_the_way",
            "out_for_delivery": "on_the_way",
        }
        status = status_aliases.get(status.lower(), status.lower())
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
                return f'<td align="center" style="width: 60px;"><div class="email-step-active" style="width: 32px; height: 32px; background: {s["color"]}; border-radius: 50%; color: white; line-height: 32px; font-weight: bold; margin: 0 auto; box-shadow: 0 0 0 4px {s["bg"]};">{step_num}</div><p style="font-size: 10px; color: {s["color"]}; margin: 4px 0 0; font-weight: bold;">{label}</p></td>'
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
              <a href="{cls._get_customer_app_url()}" class="btn-primary">Open Fudgo App</a>
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
        """Order delivered - celebration with a rating action and product images"""
        
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
                    items_html += f'<td style="padding: 4px;"><div style="width: 70px; height: 70px; border-radius: 8px; background: #FFF3E8; border: 2px solid #fff; box-shadow: 0 2px 8px rgba(0,0,0,0.1); text-align: center; line-height: 70px; font-size: 28px;">🍽️</div></td>'
            
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
          
          <a href="{cls._get_customer_app_url()}" class="btn-primary" style="padding: 16px 40px; font-size: 16px;">Open Fudgo to rate your order</a>
          <p style="margin-top: 20px;"><a href="{cls._get_customer_app_url()}" style="color: #3B1F6B; font-weight: 600; font-size: 15px;">🔄 Order Again</a></p>
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
    # PROMOTION DISCOUNT - Food-forward, responsive offer card
    # ============================================================
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
        cta_link: str = None,
        contact_phone: str = None,
        contact_address: str = None,
        contact_hours: str = None
    ) -> Dict[str, str]:
        '''Build a responsive restaurant offer email with optional food photography.'''
        def text(value):
            return escape(str(value or ""), quote=True)

        def safe_url(value, fallback=None):
            raw = str(value or "").strip()
            parsed = urlparse(raw)
            if parsed.scheme in {"http", "https"} and parsed.netloc:
                return escape(raw, quote=True)
            if raw.startswith("/") and not raw.startswith("//"):
                return escape(urljoin(cls._get_customer_app_url(), raw), quote=True)
            fallback_url = cls._get_customer_app_url() if fallback is None else fallback
            return escape(str(fallback_url), quote=True)

        user = text(user_name or "there")
        discount = text(discount_amount)
        offer_description = text(description)
        expiry = text(expiry_date)
        title = text(hero_title or "A delicious deal is waiting")
        subtitle = text(hero_subtitle or "A little something for your next meal")
        cta = text(cta_text or "Order now")
        action_url = safe_url(cta_link, cls._get_customer_app_url())

        hero_image = ""
        if hero_image_url:
            hero_src = safe_url(hero_image_url, "")
            if hero_src:
                hero_image = f'''<tr><td style="padding:0 0 16px;">
  <img src="{hero_src}" alt="Featured food from Fudgo" width="552" style="display:block;width:100%;max-width:552px;height:auto;border-radius:12px;" />
</td></tr>'''

        food_cards = []
        for item in (food_items or [])[:4]:
            name = text(item.get("name"))
            price = text(item.get("price"))
            original_price = text(item.get("original_price"))
            image_url = safe_url(item.get("image_url"), "") if item.get("image_url") else ""
            image = (
                f'<img src="{image_url}" alt="{name}" width="72" height="72" style="display:block;width:72px;height:72px;object-fit:cover;border-radius:10px;" />'
                if image_url else
                '<table role="presentation" width="72" height="72" cellpadding="0" cellspacing="0" border="0" bgcolor="#FFF3E8" style="width:72px;height:72px;background:#FFF3E8;border-radius:10px;"><tr><td align="center" valign="middle" style="font-size:28px;">🍲</td></tr></table>'
            )
            old_price = f'<span style="color:#766D66;font-size:12px;text-decoration:line-through;margin-right:6px;">{original_price}</span>' if original_price and original_price != price else ""
            food_cards.append(f'''<td class="food-item-cell" width="50%" style="width:50%;vertical-align:top;padding:6px;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#FFFFFF" style="background:#FFFFFF;border:1px solid #F0E4DA;border-radius:12px;">
    <tr><td width="84" valign="top" style="width:84px;padding:12px 0 12px 12px;">{image}</td>
      <td valign="middle" style="padding:12px;">
        <p style="margin:0 0 6px;color:#29231F;font-size:14px;line-height:1.35;font-weight:700;">{name}</p>
        <p style="margin:0;color:#3B1F6B;font-size:14px;line-height:1.4;font-weight:800;">{old_price}{price}</p>
      </td>
    </tr>
  </table>
</td>''')
        food_rows = []
        for index in range(0, len(food_cards), 2):
            cells = food_cards[index:index + 2]
            if len(cells) == 1:
                cells.append('<td class="food-item-cell" width="50%" style="width:50%;padding:6px;">&nbsp;</td>')
            food_rows.append(f'<tr>{"".join(cells)}</tr>')
        food_section = ""
        if food_rows:
            food_section = f'''<tr><td style="padding:22px 0 8px;">
  <p style="margin:0 0 8px;color:#24170D;font-size:18px;font-weight:800;">A few favourites</p>
  <p style="margin:0 0 10px;color:#716861;font-size:13px;">A taste of what is waiting for you.</p>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">{"".join(food_rows)}</table>
</td></tr>'''

        restaurant_rows = []
        for restaurant in (restaurants or [])[:4]:
            name = text(restaurant.get("name"))
            cuisines = text(restaurant.get("cuisines"))
            restaurant_url = safe_url(restaurant.get("link"))
            image_url = safe_url(restaurant.get("image_url"), "") if restaurant.get("image_url") else ""
            image = f'<img src="{image_url}" alt="{name}" width="64" height="64" style="display:block;width:64px;height:64px;object-fit:cover;border-radius:10px;" />' if image_url else ""
            restaurant_rows.append(f'''<tr><td style="padding:6px 0;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#FFFFFF" style="background:#FFFFFF;border:1px solid #F0E4DA;border-radius:12px;">
    <tr><td width="78" style="width:78px;padding:10px;">{image}</td>
      <td valign="middle" style="padding:10px 8px;">
        <p style="margin:0;color:#29231F;font-size:14px;line-height:1.35;font-weight:700;">{name}</p>
        <p style="margin:4px 0 0;color:#716861;font-size:12px;line-height:1.4;">{cuisines}</p>
      </td>
      <td align="right" valign="middle" style="padding:10px 12px;"><a href="{restaurant_url}" style="color:#3B1F6B;text-decoration:none;font-size:12px;font-weight:700;">Explore&nbsp;›</a></td>
    </tr>
  </table>
</td></tr>''')
        restaurant_section = ""
        if restaurant_rows:
            restaurant_section = f'''<tr><td style="padding:22px 0 4px;">
  <p style="margin:0 0 8px;color:#24170D;font-size:18px;font-weight:800;">Explore restaurants</p>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">{"".join(restaurant_rows)}</table>
</td></tr>'''

        terms = []
        if expiry:
            terms.append(f'<span style="font-weight:700;color:#3B1F6B;">Offer ends {expiry}</span>')
        if min_order:
            terms.append(f'<span>Minimum order: {text(min_order)}</span>')
        terms_html = "&nbsp;&nbsp;·&nbsp;&nbsp;".join(terms)
        contact_lines = []
        if contact_address:
            contact_lines.append(f'<p style="margin:4px 0;color:#716861;font-size:12px;">📍 {text(contact_address)}</p>')
        if contact_hours:
            contact_lines.append(f'<p style="margin:4px 0;color:#716861;font-size:12px;">🕒 {text(contact_hours)}</p>')
        if contact_phone:
            safe_phone = text(contact_phone)
            contact_lines.append(f'<p style="margin:4px 0;color:#716861;font-size:12px;">☎ {safe_phone}</p>')

        header = cls._header(title, f"Hi <strong>{user}</strong> — {subtitle}", "🍔")
        body = f'''<table style="max-width:600px;margin:0 auto;" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
  <tr><td class="body__details body__background" bgcolor="#FFFFFF" style="padding:24px;background:#FFFFFF;border:1px solid #F0E4DA;border-radius:14px;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
      {hero_image}
      <tr><td align="center" bgcolor="#FFF1E5" style="padding:24px 18px;background-color:#FFF1E5;border:1px solid #FFD8BA;border-radius:14px;">
        <p style="margin:0;color:#3B1F6B;font-size:11px;line-height:1.3;letter-spacing:1.5px;text-transform:uppercase;font-weight:800;">A treat for your next order</p>
        <p class="motion-enter" style="margin:8px 0 3px;color:#24170D;font-size:42px;line-height:1.05;font-weight:900;letter-spacing:-1px;">{discount} OFF</p>
        <p style="margin:0;color:#4E4037;font-size:14px;line-height:1.5;">{title}</p>
      </td></tr>
      <tr><td style="padding:18px 2px 4px;color:#4E4640;font-size:14px;line-height:1.7;">{offer_description}</td></tr>
      <tr><td align="center" style="padding:14px 0 8px;">
        <a class="btn-primary" href="{action_url}" target="_blank" rel="noopener" style="display:inline-block;padding:14px 28px;background:#FF6B00;color:#24170D;border-radius:10px;font-weight:800;text-decoration:none;">{cta}</a>
      </td></tr>
      {f'<tr><td align="center" style="padding:4px 0 12px;color:#716861;font-size:12px;line-height:1.6;">{terms_html}</td></tr>' if terms_html else ''}
      {food_section}
      {restaurant_section}
      {f'<tr><td style="padding:18px 0 0;border-top:1px solid #F0E4DA;">{"".join(contact_lines)}</td></tr>' if contact_lines else ''}
    </table>
  </td></tr>
</table>'''
        footer = cls._footer("A good meal is always a good idea.")
        preheader = f"{discount_amount} off your next order. {description}"
        html = cls._base_template(header + body + footer, preheader)

        items_text = ""
        if food_items:
            items_text = "\n\nFEATURED ITEMS:\n" + "\n".join(
                f"  - {item.get('name', '')}: {item.get('price', '')}" for item in food_items[:4]
            )
        restaurants_text = ""
        if restaurants:
            restaurants_text = "\n\nRESTAURANTS:\n" + "\n".join(
                f"  - {restaurant.get('name', '')} ({restaurant.get('cuisines', '')})"
                for restaurant in restaurants[:4]
            )
        terms_text = f"\nOffer ends: {expiry_date}" if expiry_date else ""
        if min_order:
            terms_text += f"\nMinimum order: {min_order}"
        contact_text = "\n".join(str(value) for value in (contact_address, contact_hours, contact_phone) if value)
        contact_text = f"\n\nRestaurant details:\n{contact_text}" if contact_text else ""
        plain = f'''Hi {user_name},

{hero_title}
{hero_subtitle}

{discount_amount} OFF
{description}{terms_text}{items_text}{restaurants_text}{contact_text}

Order now: {cta_link}

© {cls._get_year()} {cls._get_company_name()}'''
        return {"subject": f"🍽️ {discount_amount} off your next order", "html": html, "plain": plain}

    # ============================================================
    # WELCOME PROMO - Gift themed, first order discount
    # ============================================================
    @classmethod
    def welcome_promo(cls, user_name: str, promo_code: str, discount_amount: str) -> Dict[str, str]:
        """Welcome promo - gift box themed with responsive light styling"""
        
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
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background: linear-gradient(135deg, #FFF3E8 0%, #FFE2CC 100%); border-radius: 12px; padding: 32px; margin-bottom: 24px; border: 2px solid #FF6B00;">
            <tr><td align="center">
              <p style="font-size: 48px; font-weight: 900; color: #3B1F6B; margin: 0;">{discount_amount}</p>
              <p style="color: #6b7280; font-size: 14px; margin: 8px 0 0;">off your first order</p>
            </td></tr>
          </table>
          
          <!-- Code Box -->
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background: #FFF3E8; border: 1px solid #FFD8BA; border-radius: 12px; padding: 20px; margin: 24px 0;">
            <tr><td align="center">
              <p style="color: #3B1F6B; font-size: 28px; font-weight: 800; letter-spacing: 4px; font-family: monospace; margin: 0;">{promo_code}</p>
              <p style="color: #9ca3af; font-size: 13px; margin: 12px 0 0;">Valid for first order only</p>
            </td></tr>
          </table>
          
          <p style="color: #4b5563; font-size: 15px; line-height: 1.6; margin: 24px 0;">Start your Fudgo journey with a treat on us! Thousands of restaurants are waiting.</p>
          
          <a href="{cls._get_customer_app_url()}" class="btn-primary" style="padding: 16px 40px; font-size: 16px;">Claim Your Gift 🎉</a>
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

Start ordering at {cls._get_customer_app_url()}!

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
        """Driver assigned - tracking/map style with responsive light styling"""
        
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
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background: linear-gradient(135deg, #FFF3E8 0%, #FFE2CC 100%); border-radius: 12px; padding: 24px; margin-bottom: 24px;">
            <tr><td align="center">
              <div style="width: 64px; height: 64px; background: #FF6B00; border-radius: 50%; display: inline-block; line-height: 64px; font-size: 28px;">👤</div>
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
          
          <a href="{cls._get_customer_app_url()}" class="btn-primary">Open Fudgo App</a>
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
        """Arriving soon - countdown timer style with responsive light styling"""
        
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
        """Account deactivated - gentle farewell design with responsive light styling"""
        
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
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background: #FFF3E8; border-radius: 12px; padding: 20px; margin: 24px 0;">
            <tr><td>
              <p style="color: #1f2937; font-size: 14px; font-weight: 600; margin: 0 0 8px;">💡 Changed Your Mind?</p>
              <p style="color: #6b7280; font-size: 14px; margin: 0; line-height: 1.5;">You can reactivate your account within 30 days by simply logging in. All your data will be restored.</p>
            </td></tr>
          </table>
          
          <p style="color: #4b5563; font-size: 15px; line-height: 1.7; margin: 24px 0;">If there's anything we could have done better, we'd love to hear from you.</p>
          
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin: 28px 0;">
            <tr>
              <td align="center">
                <a href="{cls._get_customer_app_url()}" class="btn-primary" style="margin-right: 12px;">Log in to Reactivate</a>
                <a href="{cls._get_support_url()}" style="display: inline-block; border: 1px solid #E5D8CD; color: #3B1F6B; text-decoration: none; padding: 12px 24px; border-radius: 8px; font-weight: 600;">Give Feedback</a>
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


    @classmethod
    def restaurant_invitation(cls, user_name: str, restaurant_name: str, activation_url: str, role: str = "restaurant owner") -> Dict[str, str]:
        """Invitation for a restaurant owner or staff member to activate access."""
        header = cls._header(
            "Your restaurant workspace is ready",
            f"{restaurant_name} invited you to join its Fudz Hub workspace as a {role}.",
            "🍽️",
        )
        body = f"""
  <table style="max-width:600px; margin: 0 auto;" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr><td class="body__details body__background" style="border-radius: 16px; padding: 32px; text-align: center;">
      <p style="color: #4b5563; font-size: 15px; line-height: 1.7; margin: 0 0 24px;">Hi <strong>{user_name}</strong>, you have been invited to join <strong>{restaurant_name}</strong> as a <strong>{role}</strong>.</p>
      <a href="{activation_url}" class="btn-primary">Activate your account</a>
      <p style="color: #6b7280; font-size: 12px; line-height: 1.6; margin: 24px 0 0;">Choose a password from the secure activation page. This invitation link expires after 30 minutes.</p>
      <p style="color: #9ca3af; font-size: 11px; margin-top: 18px;">If you were not expecting this invitation, you can safely ignore it.</p>
    </td></tr>
  </table>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr><td style="height: 24px;"></td></tr></table>"""
        html = cls._base_template(header + body + cls._footer("Welcome to your restaurant workspace."), "Activate your Fudz Hub restaurant workspace")
        plain = f"""Hi {user_name},

You have been invited to join {restaurant_name} as a {role}. Activate your account and choose a password here:
{activation_url}

This invitation link expires after 30 minutes.

If you were not expecting this invitation, you can safely ignore it.
"""
        return {"subject": "🍽️ Activate your Fudz Hub restaurant workspace", "html": html, "plain": plain}

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
        "restaurant_invitation": EmailTemplates.restaurant_invitation,
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
