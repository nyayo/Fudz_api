import logging
import requests
from django.conf import settings

from django.core.exceptions import ValidationError
from django.utils import timezone
from django.core.mail import EmailMessage
from django.conf import settings

from .models import User

logger = logging.getLogger(__name__)


class PlunkEmailService:
    """Utility class for common operations"""

    @staticmethod
    def send_email(data: dict) -> bool:
        """
        Send email using Plunk API

        Args:
            data: Dictionary containing:
                - to_email: Recipient email address
                - email_subject: Email subject line
                - email_body: Plain text or HTML email body
                - email_html: (Optional) HTML version if email_body is plain text
                - email_type: (Optional) 'html' or 'text', defaults to 'html'

        Returns:
            bool: True if email sent successfully, False otherwise
        """
        try:
            to_email = data.get("to_email")
            subject = data.get("email_subject")
            body = data.get("email_body")
            html_body = data.get("email_html")
            email_type = data.get("email_type", "html")

            if not all([to_email, subject, body]):
                logger.error("Missing required email fields")
                return False

            # Get Plunk API key from settings
            plunk_api_key = getattr(settings, "EMAIL_PLUNK_API_KEY", None)
            # In send_email method, after getting the key:
            print(f"Using API key: {plunk_api_key[:10]}..." if plunk_api_key else "No API key found")

            if not plunk_api_key:
                logger.error("EMAIL_PLUNK_API_KEY not configured in settings")
                return False

            # Plunk API endpoint
            url = "https://api.useplunk.com/v1/send"

            # Headers for Plunk API
            headers = {
                "Authorization": f"Bearer {plunk_api_key}",
                "Content-Type": "application/json",
            }

            # Use HTML version if provided, otherwise use body
            email_content = html_body if html_body else body

            # Payload for Plunk API
            payload = {
                "to": to_email,
                "subject": subject,
                "body": email_content,
                "type": email_type,
            }

            # Optional: Add sender name if configured
            sender_name = getattr(settings, "EMAIL_SENDER_NAME", None)
            if sender_name:
                payload["name"] = sender_name

            # Optional: Add reply-to if configured
            reply_to = getattr(settings, "EMAIL_REPLY_TO", None)
            if reply_to:
                payload["reply"] = reply_to

            # Send the email via Plunk API
            response = requests.post(url, json=payload, headers=headers, timeout=10)

            if response.status_code == 200:
                logger.info(f"Email sent successfully to {to_email}")
                return True
            else:
                logger.error(
                    f"Failed to send email to {to_email}. "
                    f"Status: {response.status_code}, Response: {response.text}"
                )
                return False

        except requests.exceptions.Timeout:
            logger.error(f"Timeout sending email to {data.get('to_email')}")
            return False

        except requests.exceptions.RequestException as e:
            logger.error(
                f"Request error sending email to {data.get('to_email')}: {str(e)}"
            )
            return False

        except Exception as e:
            logger.error(
                f"Unexpected error sending email to {data.get('to_email')}: {str(e)}"
            )
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
        results = {"sent": 0, "failed": 0, "failed_addresses": []}

        try:
            for recipient in recipients:
                email_data_copy = email_data.copy()
                email_data_copy["to_email"] = recipient

                if PlunkEmailService.send_email(email_data_copy):
                    results["sent"] += 1
                    logger.info(f"Bulk email sent to {recipient}")
                else:
                    results["failed"] += 1
                    results["failed_addresses"].append(recipient)
                    logger.warning(f"Failed to send bulk email to {recipient}")

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
        results = {"sent": 0, "failed": 0, "failed_addresses": []}

        try:
            email_data = {
                "email_subject": template_data.get("subject"),
                "email_body": template_data.get("plain"),
                "email_html": template_data.get("html"),
                "email_type": "html",
            }

            for recipient in recipients:
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
        """
        Validate that Plunk API is properly configured

        Returns:
            bool: True if configuration is valid
        """
        try:
            plunk_api_key = getattr(settings, "EMAIL_PLUNK_API_KEY", None)

            if not plunk_api_key:
                logger.error("EMAIL_PLUNK_API_KEY is not configured in settings")
                return False

            # Optional: Test API key with a simple request
            # This could be implemented if Plunk has a test endpoint

            logger.info("Plunk API configuration validated")
            return True

        except Exception as e:
            logger.error(f"Error validating Plunk configuration: {str(e)}")
            return False



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


def send_normal_email(data):
    email=EmailMessage(
        subject=data['email_subject'],
        body=data['email_body'],
        from_email=settings.EMAIL_HOST_USER,
        to=[data['to_email']]
    )
    email.send()