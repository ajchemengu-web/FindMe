"""
Phone-based invites for "watch someone who doesn't have FindMe yet" -- new capability,
no Supabase-era equivalent. The original app's "Someone else" flow could only target an
existing account (GET /auth/lookup); this lets a request wait for someone to sign up.
See app/models/pending_invite.py.
"""
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.core.errors import AppError
from app.models.pending_invite import PendingInvite
from app.models.user import User
from app.services import authz
from app.services.phone import normalize_phone
from app.services.sms import send_sms

INVITE_EXPIRES_DAYS = 30


async def invite_or_request(db: AsyncSession, *, inviter: User, contact: str, scope: str) -> tuple[str, User | None]:
    """If `contact` already has an account, creates a real Consent request immediately
    (return "requested"). Otherwise stores a PendingInvite and sends an SMS
    (return "invited") -- link_pending_invites() below creates the real request once
    they sign up with this phone number."""
    phone = normalize_phone(contact)

    existing = await db.scalar(select(User).where(User.phone == phone))
    if existing is not None:
        await authz.create_consent_request(db, grantor_id=existing.id, grantee=inviter, scope=scope, expires_at=None)
        return "requested", existing

    settings = get_settings()
    invite = PendingInvite(
        id=uuid.uuid4(),
        inviter_id=inviter.id,
        contact_phone=phone,
        scope=scope,
        expires_at=datetime.now(timezone.utc) + timedelta(days=INVITE_EXPIRES_DAYS),
    )
    db.add(invite)
    await db.flush()

    who = inviter.display_name or inviter.username
    link = f" {settings.frontend_url.rstrip('/')}/sign-up" if settings.frontend_url else ""
    await send_sms(
        phone,
        f"{who} invited you to FindMe to share your location.{link} Sign up with this phone number to respond.",
    )
    return "invited", None


async def link_pending_invites(db: AsyncSession, new_user: User) -> None:
    """Called from auth_service.signup() right after a new user is created. Additive
    and never blocks signup, same philosophy as signup()'s referral-code linking: an
    invite that's expired, or would now violate a plan limit, is just left unconsumed
    rather than failing the whole signup."""
    if not new_user.phone:
        return

    now = datetime.now(timezone.utc)
    rows = (
        (
            await db.execute(
                select(PendingInvite).where(
                    PendingInvite.contact_phone == new_user.phone,
                    PendingInvite.consumed_at.is_(None),
                    PendingInvite.expires_at > now,
                )
            )
        )
        .scalars()
        .all()
    )

    for invite in rows:
        inviter = await db.get(User, invite.inviter_id)
        if inviter is not None:
            try:
                await authz.create_consent_request(db, grantor_id=new_user.id, grantee=inviter, scope=invite.scope, expires_at=None)
            except AppError:
                pass  # plan limit hit, duplicate, self-invite -- skip, don't block signup
        invite.consumed_at = now
