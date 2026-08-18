"""
users -- merges Supabase's auth.users (email, hashed password, phone confirmation
state) with public.profiles (username, phone, display name, plan, referral code) into
one table, since this service owns auth directly instead of delegating it.

plan_tier / plan_renews_at / referral_code / stripe_customer_id-equivalent fields are
NOT writable through the generic "update my profile" endpoint -- see
app/routers/auth.py's PATCH /auth/me, which only accepts display_name/avatar_url. That
mirrors 20260702121200_phone_verification.sql's column-privilege revoke
(`grant update (display_name, avatar_url) ... to authenticated`): the enforcement moves
from a Postgres GRANT to "the endpoint's pydantic schema simply doesn't expose the
other fields," same guarantee, application layer instead of database layer.
"""
import uuid
from datetime import datetime

from sqlalchemy import Boolean, CheckConstraint, DateTime, Index, String, text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base
from app.models.common import created_at_col, updated_at_col, uuid_pk


class User(Base):
    __tablename__ = "users"
    __table_args__ = (
        CheckConstraint("plan_tier in ('free','plus','pro')", name="users_plan_tier_check"),
        # Case-insensitive lookup indexes (sign-in accepts any casing); uniqueness
        # itself stays case-sensitive via the plain unique= below, same split the
        # original schema had (a separate `profiles_username_idx on lower(username)`
        # next to a case-sensitive `unique` column constraint).
        Index("users_username_lower_idx", text("lower(username)")),
        Index("users_email_lower_idx", text("lower(email)")),
    )

    id: Mapped[uuid.UUID] = uuid_pk()

    # ---------- was auth.users ----------
    email: Mapped[str] = mapped_column(String, nullable=False, unique=True)
    hashed_password: Mapped[str] = mapped_column(String, nullable=False)

    # ---------- was public.profiles ----------
    username: Mapped[str] = mapped_column(String, nullable=False, unique=True)
    phone: Mapped[str | None] = mapped_column(String, unique=True)
    phone_verified: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    display_name: Mapped[str | None] = mapped_column(String)
    avatar_url: Mapped[str | None] = mapped_column(String)

    plan_tier: Mapped[str] = mapped_column(String, nullable=False, default="free")
    plan_renews_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    referral_code: Mapped[str] = mapped_column(String, nullable=False, unique=True)

    created_at: Mapped[datetime] = created_at_col()
    updated_at: Mapped[datetime] = updated_at_col()
