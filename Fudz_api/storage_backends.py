from storages.backends.s3boto3 import S3Boto3Storage
from django.conf import settings


class CloudflareR2Storage(S3Boto3Storage):
    """
    Custom storage backend for Cloudflare R2.
    Uses S3-compatible API with R2-specific configuration.
    """

    def __init__(self, *args, **kwargs):
        kwargs.setdefault("bucket_name", settings.R2_BUCKET_NAME)
        kwargs.setdefault("endpoint_url", f"https://{settings.R2_ACCOUNT_ID}.r2.cloudflarestorage.com")
        kwargs.setdefault("access_key", settings.R2_ACCESS_KEY_ID)
        kwargs.setdefault("secret_key", settings.R2_SECRET_ACCESS_KEY)
        kwargs.setdefault("custom_domain", settings.R2_CUSTOM_DOMAIN)
        kwargs.setdefault("default_acl", None)  # R2 doesn't use ACLs
        kwargs.setdefault("signature_version", "s3v4")
        kwargs.setdefault("region_name", "auto")
        super().__init__(*args, **kwargs)

    def url(self, name):
        """
        Return the public URL for the file.
        Uses the custom domain (public bucket URL or Cloudflare CDN).
        """
        if self.custom_domain:
            return f"https://{self.custom_domain}/{name}"
        return super().url(name)
