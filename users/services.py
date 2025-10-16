from django.core.exceptions import ValidationError
from django.utils import timezone
from django.core.mail import EmailMessage
from django.conf import settings

from .models import User


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