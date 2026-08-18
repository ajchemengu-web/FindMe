"""
FastAPI dependencies -- get_current_user is the one thing every protected router
depends on; it's the entire replacement for "RLS reads auth.uid() from the request's
JWT automatically." Here, nothing is automatic: every query that used to rely on RLS
now explicitly filters by current_user.id or goes through app/services/authz.py.
"""
from typing import Annotated

from fastapi import Depends, Header, HTTPException, status
from jose import JWTError
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.core.security import decode_access_token
from app.database import get_db
from app.models.user import User

DbSession = Annotated[AsyncSession, Depends(get_db)]


async def get_current_user(
    db: DbSession,
    authorization: Annotated[str | None, Header()] = None,
) -> User:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Missing or malformed Authorization header.")
    token = authorization.split(" ", 1)[1].strip()
    try:
        user_id = decode_access_token(token)
    except (JWTError, ValueError):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid or expired access token.")

    user = await db.get(User, user_id)
    if user is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "User no longer exists.")
    return user


CurrentUser = Annotated[User, Depends(get_current_user)]


def require_cron_secret(x_cron_secret: Annotated[str | None, Header()] = None) -> None:
    """Gate for /ingest/* -- same role as assertCronSecret() in the old
    _shared/supabaseAdmin.ts, protecting endpoints meant to be hit only by a scheduler,
    never a signed-in user."""
    settings = get_settings()
    if not settings.cron_shared_secret or x_cron_secret != settings.cron_shared_secret:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "unauthorized")
