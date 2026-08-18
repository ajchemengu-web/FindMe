"""
Real phone verification -- this service's replacement for
supabase.auth.updateUser({phone}) + supabase.auth.verifyOtp({..., type:
'phone_change'}) + the on_auth_user_phone_change trigger
(20260702121200_phone_verification.sql). Three differences from the Supabase version,
all because there's no managed Auth provider to lean on anymore:

  1. OTP codes are generated, hashed, and expiry/attempt-limited here (phone_otps
     table), not inside a third-party Auth service.
  2. Only THIS module ever sets users.phone_verified = True -- mirrors the old
     column-privilege revoke's guarantee, just enforced by "no other code path touches
     this column" instead of a GRANT/REVOKE.
  3. Resend cooldown (settings.phone_otp_resend_cooldown_seconds) is enforced
     server-side here, not just client-side the way verify-phone.tsx's 60s countdown
     was (findme_app/README.md flagged that as a UX-only control, not real
     rate-limiting).
"""
import hashlib
import secrets
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.models.phone_otp import PhoneOtp
from app.models.user import User
from app.services.sms import send_sms


class PhoneVerificationError(Exception):
    pass


def _hash_code(code: str) -> str:
    return hashlib.sha256(code.encode("utf-8")).hexdigest()


async def send_phone_otp(db: AsyncSession, user: User, phone: str) -> None:
    settings = get_settings()
    now = datetime.now(timezone.utc)

    cooldown_cutoff = now - timedelta(seconds=settings.phone_otp_resend_cooldown_seconds)
    recent = await db.scalar(
        select(PhoneOtp)
        .where(PhoneOtp.user_id == user.id, PhoneOtp.created_at > cooldown_cutoff)
        .order_by(PhoneOtp.created_at.desc())
        .limit(1)
    )
    if recent is not None:
        raise PhoneVerificationError(
            f"Please wait before requesting another code "
            f"({settings.phone_otp_resend_cooldown_seconds}s cooldown)."
        )

    code = f"{secrets.randbelow(1_000_000):06d}"
    otp = PhoneOtp(
        id=uuid.uuid4(),
        user_id=user.id,
        phone=phone,
        code_hash=_hash_code(code),
        expires_at=now + timedelta(minutes=settings.phone_otp_ttl_minutes),
    )
    db.add(otp)
    await db.flush()

    await send_sms(phone, f"Your FindMe verification code is {code}. It expires in "
                           f"{settings.phone_otp_ttl_minutes} minutes.")


async def confirm_phone_otp(db: AsyncSession, user: User, phone: str, code: str) -> None:
    now = datetime.now(timezone.utc)
    otp = await db.scalar(
        select(PhoneOtp)
        .where(PhoneOtp.user_id == user.id, PhoneOtp.phone == phone, PhoneOtp.consumed_at.is_(None))
        .order_by(PhoneOtp.created_at.desc())
        .limit(1)
    )
    if otp is None or otp.expires_at < now:
        raise PhoneVerificationError("No pending verification code for this number. Request a new one.")

    if otp.attempts >= 5:
        raise PhoneVerificationError("Too many incorrect attempts. Request a new code.")

    if otp.code_hash != _hash_code(code.strip()):
        otp.attempts += 1
        await db.flush()
        raise PhoneVerificationError("Incorrect code.")

    otp.consumed_at = now
    user.phone = phone
    user.phone_verified = True
    await db.flush()
