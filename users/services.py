import logging

import requests
from django.conf import settings
from django.core.exceptions import ValidationError
from django.core.mail import EmailMessage
from django.utils import timezone

from .models import User

logger = logging.getLogger(__name__)


class PlunkEmailService:
    """Utility class for common operations"""

    @staticmethod
    def send_email(data: dict) -> bool:
        """Send an HTML/plain transactional email using the configured provider."""
        try:
            to_email = data.get("to_email")
            subject = data.get("email_subject")
            body = data.get("email_body")
            html_body = data.get("email_html")
            if not all([to_email, subject, body]):
                logger.error("Missing required email fields")
                return False
            if getattr(settings, "EMAIL_PROVIDER", "plunk").lower() == "resend":
                return PlunkEmailService._send_via_resend(
                    to_email, subject, html_body or body, body
                )
            api_key = getattr(settings, "EMAIL_PLUNK_API_KEY", None)
            if not api_key:
                logger.error("EMAIL_PLUNK_API_KEY is not configured")
                return False
            url = f"{getattr(settings, 'PLUNK_BASE_URL', 'https://next-api.useplunk.com').rstrip('/')}/v1/send"
            response = requests.post(
                url,
                json={"to": to_email, "subject": subject, "body": html_body or body},
                headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
                timeout=10,
            )
            if 200 <= response.status_code < 300:
                try:
                    result = response.json()
                    if result.get("success") is False:
                        logger.error("Plunk rejected email to %s: %s", to_email, result)
                        return False
                except ValueError:
                    pass
                logger.info("Email sent via Plunk to %s", to_email)
                return True
            logger.error("Plunk failed for %s: %s %s", to_email, response.status_code, response.text)
            return False
        except requests.exceptions.Timeout:
            logger.error("Timeout sending email to %s", data.get("to_email"))
            return False
        except requests.exceptions.RequestException as exc:
            logger.error("Email request failed for %s: %s", data.get("to_email"), exc)
            return False
        except Exception:
            logger.exception("Unexpected email error for %s", data.get("to_email"))
            return False

    @staticmethod
    def _send_via_resend(to_email, subject, html, text) -> bool:
        api_key = getattr(settings, "RESEND_API_KEY", None)
        from_email = getattr(settings, "DEFAULT_FROM_EMAIL", None)
        if not api_key or not from_email:
            logger.error("RESEND_API_KEY or DEFAULT_FROM_EMAIL not configured")
            return False
    
        sender_name = getattr(settings, "EMAIL_SENDER_NAME", None)
        payload = {
            "from": f"{sender_name} <{from_email}>" if sender_name else from_email,
            "to": [to_email],
            "subject": subject,
            "html": html,
            "text": text,
        }
        reply_to = getattr(settings, "EMAIL_REPLY_TO", None)
        if reply_to:
            payload["reply_to"] = reply_to
    
        try:
            r = requests.post(
                "https://api.resend.com/emails",
                json=payload,
                headers={"Authorization": f"Bearer {api_key}"},
                timeout=10,
            )
        except requests.exceptions.RequestException as e:
            logger.error(f"Resend request error for {to_email}: {e}")
            return False
    
        if 200 <= r.status_code < 300:
            logger.info("Email sent via Resend to %s", to_email)
            return True
        logger.error("Resend failed for %s: %s %s", to_email, r.status_code, r.text)
        return False

    @staticmethod
    def send_templated_email(to_email: str, template_data: dict) -> bool:
        """
        Send email using template data from email_templates.py

        Args:
            to_email: Recipient email address
            template_data: Dictionary with 'subject', 'html', and 'plain' keys

        Returns:
            bool: True if email sent successfully, False otherwise
        """
        try:
            if not to_email:
                logger.info("Skipping email send: recipient has no email address")
                return False
                
            if not template_data:
                logger.error("No template data provided")
                return False

            email_data = {
                "to_email": to_email,
                "email_subject": template_data.get("subject"),
                "email_body": template_data.get("plain"),  # Fallback plain text
                "email_html": template_data.get("html"),  # Primary HTML content
                "email_type": "html",
            }

            return PlunkEmailService.send_email(email_data)

        except Exception as e:
            logger.error(f"Failed to send templated email to {to_email}: {str(e)}")
            return False
            
    @staticmethod
    def send_bulk_email(recipients: list, email_data: dict) -> dict:
        """
        Send email to multiple recipients using Plunk API

        Args:
            recipients: List of email addresses
            email_data: Email content dictionary

        Returns:
            dict: Success/failure statistics
        """
        results = {"sent": 0, "failed": 0, "skipped": 0, "failed_addresses": []}

        try:
            for recipient in recipients:
                if not recipient:
                    results["skipped"] += 1
                    continue
            
                email_data_copy = email_data.copy()
                email_data_copy["to_email"] = recipient
            
                if PlunkEmailService.send_email(email_data_copy):
                    results["sent"] += 1
                else:
                    results["failed"] += 1
                    results["failed_addresses"].append(recipient)

            logger.info(
                f"Bulk email completed: {results['sent']} sent, "
                f"{results['failed']} failed"
            )

        except Exception as e:
            logger.error(f"Error in bulk email sending: {str(e)}")

        return results

    @staticmethod
    def send_bulk_templated_email(recipients: list, template_data: dict) -> dict:
        """
        Send templated email to multiple recipients

        Args:
            recipients: List of email addresses
            template_data: Template data from email_templates.py

        Returns:
            dict: Success/failure statistics
        """
        results = {"sent": 0, "failed": 0, "skipped": 0, "failed_addresses": []}

        try:
            email_data = {
                "email_subject": template_data.get("subject"),
                "email_body": template_data.get("plain"),
                "email_html": template_data.get("html"),
                "email_type": "html",
            }

            for recipient in recipients:
                if not recipient:
                    results["skipped"] += 1
                    continue
                    
                email_data_copy = email_data.copy()
                email_data_copy["to_email"] = recipient

                if PlunkEmailService.send_email(email_data_copy):
                    results["sent"] += 1
                else:
                    results["failed"] += 1
                    results["failed_addresses"].append(recipient)

            logger.info(
                f"Bulk templated email completed: {results['sent']} sent, "
                f"{results['failed']} failed"
            )

        except Exception as e:
            logger.error(f"Error in bulk templated email sending: {str(e)}")

        return results

    @staticmethod
    def format_email_address(name: str, email: str) -> str:
        """
        Format email address with name (for display purposes)

        Args:
            name: User's name
            email: Email address

        Returns:
            str: Formatted email address
        """
        return f"{name} <{email}>"

    @staticmethod
    def validate_plunk_config() -> bool:
        """Validate that the selected email provider has the required settings."""
        provider = getattr(settings, "EMAIL_PROVIDER", "plunk").lower()
        if provider == "resend":
            valid = bool(getattr(settings, "RESEND_API_KEY", None) and getattr(settings, "DEFAULT_FROM_EMAIL", None))
            if not valid:
                logger.error("RESEND_API_KEY and DEFAULT_FROM_EMAIL are required")
            return valid
        valid = bool(getattr(settings, "EMAIL_PLUNK_API_KEY", None))
        if not valid:
            logger.error("EMAIL_PLUNK_API_KEY is not configured")
        return valid

class OTPService:
    @staticmethod
    def send_otp(email, otp):
        """
        Send OTP via email using your preferred email provider
        Examples: SendGrid, AWS SES, local SMTP server
        """
        message = f"Your verification code is: {otp}. Valid for 10 minutes."

        # Example with SendGrid (uncomment and configure)
        # from sendgrid import SendGridAPIClient
        # from sendgrid.helpers.mail import Mail
        # sg = SendGridAPIClient(settings.SENDGRID_API_KEY)
        # email_message = Mail(
        #     from_email=settings.DEFAULT_FROM_EMAIL,
        #     to_emails=email,
        #     subject="Your OTP Code",
        #     plain_text_content=message
        # )
        # response = sg.send(email_message)

        # Example with a generic email API
        # response = requests.post('YOUR_EMAIL_API_ENDPOINT', {
        #     'email': email,
        #     'message': message,
        #     'api_key': settings.EMAIL_API_KEY
        #     body=message,
        #     from_=settings.TWILIO_PHONE_NUMBER,
        #     to=phone_number
        # )

        # Example with a generic SMS API
        # response = requests.post('YOUR_SMS_API_ENDPOINT', {
        #     'phone': phone_number,
        #     'message': message,
        #     'api_key': settings.SMS_API_KEY
        # })

        # For development, just print the OTP
        print(f"Email to {email}: {message}")
        return True


class SMSService:
    """Service for sending SMS messages via TextBee (https://textbee.dev)"""

    BASE_URL = "https://sms.unshifter.site/api/v1"

    @staticmethod
    def send_otp(phone: str, otp: str) -> bool:
        """
        Send OTP via SMS using TextBee API.

        Requires these settings in settings.py:
            TEXTBEE_API_KEY = "your_api_key"
            TEXTBEE_DEVICE_ID = "your_device_id"

        Args:
            phone: Phone number in international format (e.g., +254712345678)
            otp: The OTP code to send

        Returns:
            bool: True if SMS sent successfully, False otherwise
        """
        message = f"Your Fudz verification code is: {otp}. Valid for 10 minutes."

        try:
            api_key = getattr(settings, "TEXTBEE_API_KEY", None)
            device_id = getattr(settings, "TEXTBEE_DEVICE_ID", None)

            if not api_key or not device_id:
                logger.warning(
                    "TEXTBEE_API_KEY or TEXTBEE_DEVICE_ID not configured. "
                    "Falling back to dev mode."
                )
                print(f"[DEV] SMS to {phone}: {message}")
                return True

            url = f"{SMSService.BASE_URL}/gateway/devices/{device_id}/send-sms"

            headers = {
                "x-api-key": api_key,
                "Content-Type": "application/json",
            }

            payload = {
                "recipients": [phone],
                "message": message,
            }

            response = requests.post(url, json=payload, headers=headers, timeout=30)

            if 200 <= response.status_code < 300:
                logger.info(f"SMS sent to {phone} via TextBee")
                return True
            else:
                logger.error(
                    f"TextBee SMS failed to {phone}. "
                    f"Status: {response.status_code}, Response: {response.text}"
                )
                return False

        except requests.exceptions.Timeout:
            logger.error(f"Timeout sending SMS to {phone} via TextBee")
            return False

        except requests.exceptions.RequestException as e:
            logger.error(f"Request error sending SMS to {phone}: {str(e)}")
            return False

        except Exception as e:
            logger.error(f"Failed to send SMS to {phone}: {str(e)}")
            return False

    @staticmethod
    def send_bulk_sms(phones: list, message: str) -> dict:
        """
        Send SMS to multiple recipients via TextBee API.

        Args:
            phones: List of phone numbers in international format
            message: The message to send

        Returns:
            dict: Result with success status and details
        """
        try:
            api_key = getattr(settings, "TEXTBEE_API_KEY", None)
            device_id = getattr(settings, "TEXTBEE_DEVICE_ID", None)

            if not api_key or not device_id:
                logger.warning("TextBee not configured. Falling back to dev mode.")
                print(f"[DEV] Bulk SMS to {phones}: {message}")
                return {"success": True, "dev_mode": True}

            url = f"{SMSService.BASE_URL}/gateway/devices/{device_id}/send-sms"

            headers = {
                "x-api-key": api_key,
                "Content-Type": "application/json",
            }

            payload = {
                "recipients": phones,
                "message": message,
            }

            response = requests.post(url, json=payload, headers=headers, timeout=30)

            if response.status_code == 200:
                logger.info(f"Bulk SMS sent to {len(phones)} recipients via TextBee")
                return {"success": True, "data": response.json()}
            else:
                logger.error(f"TextBee bulk SMS failed: {response.text}")
                return {"success": False, "error": response.text}

        except Exception as e:
            logger.error(f"Failed to send bulk SMS: {str(e)}")
            return {"success": False, "error": str(e)}

    @staticmethod
    def validate_phone_number(phone: str) -> bool:
        """
        Validate phone number format (E.164 format)

        Args:
            phone: Phone number to validate

        Returns:
            bool: True if valid format
        """
        import re

        pattern = r"^\+?[1-9]\d{1,14}$"
        return bool(re.match(pattern, phone))


def send_normal_email(data):
    email = EmailMessage(
        subject=data["email_subject"],
        body=data["email_body"],
        from_email=settings.EMAIL_HOST_USER,
        to=[data["to_email"]],
    )
    email.send()
