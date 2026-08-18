"""referrals / referral_commissions -- ported from 20260702121400_referral_commissions.sql.
referrer_code generation + referral-row creation happens in app/services/auth.py's
signup flow (replacing handle_new_user()'s referral-linking half); commission creation
happens in app/routers/billing.py's mpesa callback handler (replacing
mpesa-stk-callback's referral_commissions insert)."""
import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base
from app.models.common import created_at_col


class Referral(Base):
    __tablename__ = "referrals"
    __table_args__ = (CheckConstraint("referrer_id <> referred_id", name="referrals_no_self_referral"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    referrer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    referred_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True
    )
    referral_code: Mapped[str] = mapped_column(String, nullable=False)
    created_at: Mapped[datetime] = created_at_col()


class ReferralCommission(Base):
    __tablename__ = "referral_commissions"
    __table_args__ = (
        CheckConstraint("plan_tier in ('plus','pro')", name="referral_commissions_plan_tier_check"),
        CheckConstraint("amount_paid_cents >= 0", name="referral_commissions_amount_check"),
        CheckConstraint("commission_cents >= 0", name="referral_commissions_commission_check"),
        CheckConstraint("status in ('pending','paid')", name="referral_commissions_status_check"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    referral_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("referrals.id", ondelete="CASCADE"), nullable=False, unique=True
    )
    referrer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    referred_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    plan_tier: Mapped[str] = mapped_column(String, nullable=False)
    amount_paid_cents: Mapped[int] = mapped_column(Integer, nullable=False)
    commission_cents: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[str] = mapped_column(String, nullable=False, default="pending")
    created_at: Mapped[datetime] = created_at_col()
