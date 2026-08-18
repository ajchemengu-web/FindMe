"""
Password hashing + JWT/refresh-token primitives -- this is the entire replacement for
Supabase Auth's GoTrue service. Nothing here talks to a third party; it's all local
bcrypt + HMAC-signed JWTs.

Design:
  - Access tokens are stateless JWTs (HS256, short-lived -- 15 min default). Verifying
    one is just a signature + expiry check, no DB round trip, same tradeoff GoTrue's
    own access tokens made.
  - Refresh tokens are opaque random strings, NOT JWTs. Only a SHA-256 hash of one is
    ever stored (app.models.refresh_token.RefreshToken), so a leaked database dump
    still can't be replayed as valid tokens. This is what makes logout / "log out
    everywhere" / reuse revocation actually possible -- a stateless JWT refresh token
    couldn't be revoked before its own expiry.
"""
import hashlib
import re
import secrets
import uuid
from datetime import datetime, timedelta, timezone

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.config import get_settings

settings = get_settings()
_pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

ACCESS_TOKEN_TYPE = "access"


def hash_password(plain_password: str) -> str:
    return _pwd_context.hash(plain_password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return _pwd_context.verify(plain_password, hashed_password)


def create_access_token(user_id: uuid.UUID) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(user_id),
        "type": ACCESS_TOKEN_TYPE,
        "iat": now,
        "exp": now + timedelta(minutes=settings.access_token_expires_minutes),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def decode_access_token(token: str) -> uuid.UUID:
    """Returns the user id encoded in a valid access token, or raises JWTError /
    ValueError if the token is missing, expired, malformed, or not an access token."""
    payload = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
    if payload.get("type") != ACCESS_TOKEN_TYPE:
        raise JWTError("not an access token")
    return uuid.UUID(payload["sub"])


def generate_refresh_token() -> str:
    """256 bits of randomness, URL-safe -- this raw value is returned to the client
    exactly once and never stored; only its hash (see hash_token below) lives in the
    database."""
    return secrets.token_urlsafe(48)


def hash_token(raw_token: str) -> str:
    return hashlib.sha256(raw_token.encode("utf-8")).hexdigest()


# ---------- password strength ----------
# Server-side enforcement of the same policy findme_app's passwordStrength.ts checked
# client-side only (findme_app/README.md's "Known gaps" flagged that as UX, not the
# real security boundary, because Supabase Auth's own password policy -- a per-project
# Dashboard setting -- was the thing that would have actually enforced it). This
# service has no separate managed auth layer to defer that to, so it has to be real
# here, at signup time, server-side.
_COMMON_PASSWORDS = {
    "password", "password1", "password123", "12345678", "123456789", "qwerty123",
    "letmein1", "welcome123", "admin1234", "iloveyou1", "111111111", "changeme1",
}


def validate_password_strength(password: str) -> list[str]:
    """Returns a list of human-readable problems; empty list means the password passes."""
    problems: list[str] = []
    if len(password) < 10:
        problems.append("Password must be at least 10 characters long.")

    classes_present = sum(
        bool(re.search(pattern, password))
        for pattern in (r"[a-z]", r"[A-Z]", r"\d", r"[^a-zA-Z0-9]")
    )
    if classes_present < 3:
        problems.append(
            "Password must include at least 3 of: lowercase, uppercase, digit, symbol."
        )

    if password.lower() in _COMMON_PASSWORDS:
        problems.append("That password is too common. Choose something less guessable.")

    return problems
