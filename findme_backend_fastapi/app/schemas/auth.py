import uuid
from datetime import datetime

from pydantic import BaseModel, EmailStr, Field


class SignupRequest(BaseModel):
    email: EmailStr
    password: str
    username: str = Field(min_length=3, max_length=32, pattern=r"^[a-zA-Z0-9_.]+$")
    phone: str | None = None
    display_name: str | None = None
    referral_code: str | None = None


class LoginRequest(BaseModel):
    # Was resolve_login_email(identifier) -- accepts username, phone, or email.
    identifier: str
    password: str


class RefreshRequest(BaseModel):
    refresh_token: str


class GoogleSignInRequest(BaseModel):
    # The ID token (JWT) google_sign_in/GoogleSignIn.authentication hands back on the
    # client -- verified server-side against Google's public keys, never trusted as-is.
    id_token: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class UserOut(BaseModel):
    id: uuid.UUID
    email: EmailStr
    username: str
    phone: str | None
    phone_verified: bool
    display_name: str | None
    avatar_url: str | None
    plan_tier: str
    plan_renews_at: datetime | None
    referral_code: str
    created_at: datetime

    model_config = {"from_attributes": True}


class UpdateProfileRequest(BaseModel):
    # display_name/avatar_url mirror the old `grant update` allowlist. username/email
    # are new -- both go through auth_service.update_profile()'s uniqueness checks
    # (same constraints signup() enforces) before being applied.
    display_name: str | None = None
    avatar_url: str | None = None
    username: str | None = Field(default=None, min_length=3, max_length=32, pattern=r"^[a-zA-Z0-9_.]+$")
    email: EmailStr | None = None


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str


class SendPhoneOtpRequest(BaseModel):
    phone: str


class ConfirmPhoneOtpRequest(BaseModel):
    phone: str
    code: str


class ProfileLookupOut(BaseModel):
    # Mirrors find_profile_for_invite() -- deliberately narrow.
    id: uuid.UUID
    username: str
    display_name: str | None
