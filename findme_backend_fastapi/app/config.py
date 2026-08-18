"""
FindMe backend -- settings.

Everything here has a Supabase-era equivalent noted in the comment so the migration
from findme_backend (Supabase) to this service is traceable field-by-field.
"""
from functools import lru_cache
from typing import Literal

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # ---------- core ----------
    env: Literal["dev", "test", "prod"] = "dev"
    # Was SUPABASE_URL/SUPABASE_SERVICE_ROLE_KEY. Now a plain Postgres+PostGIS DSN --
    # asyncpg driver, e.g. postgresql+asyncpg://findme:findme@localhost:5432/findme
    database_url: str = "postgresql+asyncpg://findme:findme@localhost:5432/findme"

    # ---------- auth (replaces Supabase Auth entirely) ----------
    jwt_secret: str = "dev-secret-change-me"
    jwt_algorithm: str = "HS256"
    access_token_expires_minutes: int = 15
    refresh_token_expires_days: int = 30

    # ---------- Google sign-in ----------
    # OAuth 2.0 Client ID from Google Cloud Console (APIs & Services -> Credentials).
    # Verifies the ID token the Flutter app gets from google_sign_in -- POST
    # /auth/google is a no-op 501 until this is set.
    google_client_id: str = ""

    # ---------- edge-function-equivalent cron gate ----------
    # Same purpose as CRON_SHARED_SECRET in the Supabase version -- required on
    # /ingest/* endpoints so they aren't wide open to anyone who finds the URL.
    cron_shared_secret: str = ""

    # ---------- news / conflict feeds ----------
    acled_api_key: str = ""
    news_api_key: str = ""  # Guardian Open Platform key

    # ---------- SMS / phone verification ----------
    # Supabase Auth used to own this (a configured phone provider, e.g. Twilio, behind
    # supabase.auth.updateUser/verifyOtp). This service now owns it directly.
    sms_provider: Literal["console", "twilio"] = "console"
    twilio_account_sid: str = ""
    twilio_auth_token: str = ""
    twilio_from_number: str = ""
    phone_otp_ttl_minutes: int = 10
    phone_otp_resend_cooldown_seconds: int = 60

    # ---------- billing: M-Pesa (Daraja) -- the app's actual payment path ----------
    mpesa_consumer_key: str = ""
    mpesa_consumer_secret: str = ""
    mpesa_shortcode: str = "174379"
    mpesa_passkey: str = ""
    mpesa_base_url: str = "https://sandbox.safaricom.co.ke"
    # Publicly reachable base URL for this API, used to build the Daraja CallBackURL
    # (mirrors mpesa-stk-push's `${SUPABASE_URL}/functions/v1/mpesa-stk-callback`).
    public_base_url: str = "http://localhost:8000"

    # ---------- object storage (replaces Supabase Storage) ----------
    s3_endpoint_url: str = "http://localhost:9000"  # MinIO locally; unset/omit for real AWS S3
    s3_region: str = "us-east-1"
    s3_access_key: str = "findme"
    s3_secret_key: str = "findme12345"
    s3_avatars_bucket: str = "avatars"
    s3_intel_photos_bucket: str = "intel-photos"
    s3_public_base_url: str = "http://localhost:9000/avatars"  # used to build public avatar URLs

    # ---------- push notifications ----------
    expo_push_url: str = "https://exp.host/--/api/v2/push/send"

    # ---------- CORS ----------
    cors_origins: list[str] = Field(default_factory=lambda: ["*"])

    @field_validator("cors_origins", mode="before")
    @classmethod
    def _split_cors_origins(cls, v: object) -> object:
        # Accept a plain comma-separated string from the environment (e.g. CORS_ORIGINS=*
        # or CORS_ORIGINS=https://a.com,https://b.com) instead of requiring JSON syntax.
        if isinstance(v, str):
            return [origin.strip() for origin in v.split(",") if origin.strip()]
        return v


@lru_cache
def get_settings() -> Settings:
    return Settings()
