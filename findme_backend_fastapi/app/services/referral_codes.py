"""Referral code generation -- ported from generate_referral_code() in
20260702121400_referral_commissions.sql. Same readable, low-ambiguity 32-symbol
alphabet (excludes 0/O and 1/I/L)."""
import secrets

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User

_ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"


async def generate_referral_code(db: AsyncSession) -> str:
    while True:
        code = "".join(secrets.choice(_ALPHABET) for _ in range(8))
        existing = await db.scalar(select(User.id).where(User.referral_code == code))
        if existing is None:
            return code
