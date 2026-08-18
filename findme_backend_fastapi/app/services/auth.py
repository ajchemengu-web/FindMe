"""
Signup / login / token issuance -- the whole replacement for Supabase Auth
(supabase.auth.signUp/signInWithPassword/refreshSession) plus the handle_new_user()
trigger's profile-creation and referral-linking side effects.
"""
import re
import secrets
import uuid
from datetime import datetime, timedelta, timezone

from google.auth.exceptions import GoogleAuthError
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.core.security import (
    create_access_token,
    generate_refresh_token,
    hash_password,
    hash_token,
    verify_password,
)
from app.models.referral import Referral
from app.models.refresh_token import RefreshToken
from app.models.user import User
from app.services.referral_codes import generate_referral_code


class AuthError(Exception):
    """Raised for any signup/login failure meant to surface as a 400/401 to the client."""


async def get_user_by_identifier(db: AsyncSession, identifier: str) -> User | None:
    """Ports resolve_login_email(identifier) -- matches username, phone, or email,
    case-insensitively for username/email (phone matches exact-normalized-string, same
    as the original)."""
    ident_stripped = identifier.strip()
    ident_lower = ident_stripped.lower()
    return await db.scalar(
        select(User).where(
            or_(
                User.phone == ident_stripped,
                func.lower(User.username) == ident_lower,
                func.lower(User.email) == ident_lower,
            )
        )
    )


async def signup(
    db: AsyncSession,
    *,
    email: str,
    password: str,
    username: str,
    phone: str | None,
    display_name: str | None,
    referral_code: str | None,
) -> User:
    existing_email = await db.scalar(select(User.id).where(User.email == email.lower()))
    if existing_email is not None:
        raise AuthError("An account with that email already exists.")

    existing_username = await db.scalar(
        select(User.id).where(User.username.ilike(username))
    )
    if existing_username is not None:
        raise AuthError("That username is already taken.")

    if phone:
        existing_phone = await db.scalar(select(User.id).where(User.phone == phone))
        if existing_phone is not None:
            raise AuthError("An account with that phone number already exists.")

    new_code = await generate_referral_code(db)
    user = User(
        id=uuid.uuid4(),
        email=email.lower(),
        hashed_password=hash_password(password),
        username=username,
        phone=phone,
        display_name=display_name or username,
        referral_code=new_code,
    )
    db.add(user)
    await db.flush()

    # ---------- referral linking, ported from handle_new_user()'s second half ----------
    # An invalid/unmatched supplied code is silently ignored -- referral tracking is
    # additive, never a sign-up blocker, same as the original.
    if referral_code:
        supplied = referral_code.strip().upper()
        referrer = await db.scalar(select(User).where(User.referral_code == supplied))
        if referrer is not None and referrer.id != user.id:
            db.add(Referral(id=uuid.uuid4(), referrer_id=referrer.id, referred_id=user.id, referral_code=supplied))

    await db.flush()
    return user


async def authenticate(db: AsyncSession, identifier: str, password: str) -> User:
    """Always raises the same generic AuthError message regardless of whether the
    identifier didn't match anything or the password was wrong for one that did --
    same anti-enumeration intent resolve_login_email's docstring described (and the
    same trade-off: this narrows but doesn't close the side channel; see this
    project's README 'Known gaps')."""
    user = await get_user_by_identifier(db, identifier)
    if user is None or not verify_password(password, user.hashed_password):
        raise AuthError("Invalid email, username, phone, or password.")
    return user


async def _unique_username_from_email(db: AsyncSession, email: str) -> str:
    """Derives a username candidate from the email local-part (sanitized to match
    SignupRequest's `^[a-zA-Z0-9_.]+$`, 3-32 chars), then disambiguates against
    existing rows with a random numeric suffix -- mirrors the constraints signup()
    enforces via SignupRequest, since a Google-created account skips that form."""
    local_part = email.split("@", 1)[0]
    base = re.sub(r"[^a-zA-Z0-9_.]", "", local_part) or "user"
    base = base[:28]  # leaves room for a disambiguating suffix within the 32-char cap
    if len(base) < 3:
        base = (base + "user")[:3]

    candidate = base
    for _ in range(20):
        existing = await db.scalar(select(User.id).where(User.username.ilike(candidate)))
        if existing is None:
            return candidate
        candidate = f"{base}{secrets.randbelow(9000) + 1000}"
    # Astronomically unlikely fallback after 20 collisions.
    return f"{base}{uuid.uuid4().hex[:8]}"


async def google_sign_in(db: AsyncSession, raw_id_token: str) -> User:
    """Verifies a Google ID token (from the client's google_sign_in flow) against
    Google's public keys + this service's OAuth client ID, then finds or creates the
    matching user by email -- the OAuth equivalent of signup()+authenticate() combined
    into one step, since there's no separate password to check.
    """
    settings = get_settings()
    if not settings.google_client_id:
        raise AuthError("Google sign-in is not configured on this server yet.")

    try:
        claims = google_id_token.verify_oauth2_token(
            raw_id_token, google_requests.Request(), settings.google_client_id
        )
    except (ValueError, GoogleAuthError):
        raise AuthError("Invalid Google sign-in token.") from None

    if not claims.get("email_verified", False):
        raise AuthError("Your Google account's email isn't verified.")
    email = str(claims["email"]).lower()

    user = await db.scalar(select(User).where(func.lower(User.email) == email))
    if user is not None:
        return user

    new_code = await generate_referral_code(db)
    username = await _unique_username_from_email(db, email)
    user = User(
        id=uuid.uuid4(),
        email=email,
        # Random, never handed to the client or usable to sign in with a password --
        # this account only ever authenticates via Google unless a "set password" flow
        # is added later.
        hashed_password=hash_password(secrets.token_urlsafe(32)),
        username=username,
        phone=None,
        display_name=claims.get("name") or username,
        referral_code=new_code,
    )
    db.add(user)
    await db.flush()
    return user


async def issue_token_pair(db: AsyncSession, user: User) -> tuple[str, str]:
    settings = get_settings()
    access = create_access_token(user.id)

    raw_refresh = generate_refresh_token()
    db.add(
        RefreshToken(
            id=uuid.uuid4(),
            user_id=user.id,
            token_hash=hash_token(raw_refresh),
            expires_at=datetime.now(timezone.utc) + timedelta(days=settings.refresh_token_expires_days),
        )
    )
    await db.flush()
    return access, raw_refresh


async def rotate_refresh_token(db: AsyncSession, raw_refresh_token: str) -> tuple[str, str]:
    """Verifies + revokes the presented refresh token and issues a new pair
    (rotation). Raises AuthError if the token is invalid, expired, or already
    revoked/rotated (possible reuse of a stolen token)."""
    token_hash = hash_token(raw_refresh_token)
    existing = await db.scalar(select(RefreshToken).where(RefreshToken.token_hash == token_hash))
    now = datetime.now(timezone.utc)

    if existing is None:
        raise AuthError("Invalid refresh token.")
    if existing.revoked_at is not None:
        raise AuthError("This refresh token has already been used or revoked.")
    if existing.expires_at < now:
        raise AuthError("Refresh token expired. Please sign in again.")

    user = await db.get(User, existing.user_id)
    if user is None:
        raise AuthError("Invalid refresh token.")

    access, new_raw_refresh = await issue_token_pair(db, user)

    # Mark old token revoked + link to its replacement (rotation chain), after the new
    # one is created so replaced_by_id can point at it.
    new_token_hash = hash_token(new_raw_refresh)
    new_row = await db.scalar(select(RefreshToken).where(RefreshToken.token_hash == new_token_hash))
    existing.revoked_at = now
    existing.replaced_by_id = new_row.id if new_row else None
    await db.flush()

    return access, new_raw_refresh


async def revoke_refresh_token(db: AsyncSession, raw_refresh_token: str) -> None:
    token_hash = hash_token(raw_refresh_token)
    existing = await db.scalar(select(RefreshToken).where(RefreshToken.token_hash == token_hash))
    if existing is not None and existing.revoked_at is None:
        existing.revoked_at = datetime.now(timezone.utc)
        await db.flush()
