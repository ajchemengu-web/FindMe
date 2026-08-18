"""/referrals -- ports get_my_referral_stats() from
20260702121400_referral_commissions.sql."""
from fastapi import APIRouter
from sqlalchemy import func, select

from app.deps import CurrentUser, DbSession
from app.models.referral import Referral, ReferralCommission
from app.schemas.referral import ReferralStatsOut

router = APIRouter(prefix="/referrals", tags=["referrals"])


@router.get("/stats", response_model=ReferralStatsOut)
async def my_referral_stats(current_user: CurrentUser, db: DbSession) -> ReferralStatsOut:
    total = await db.scalar(
        select(func.count()).select_from(Referral).where(Referral.referrer_id == current_user.id)
    )
    paying = await db.scalar(
        select(func.count()).select_from(ReferralCommission).where(ReferralCommission.referrer_id == current_user.id)
    )
    pending_cents = await db.scalar(
        select(func.coalesce(func.sum(ReferralCommission.commission_cents), 0)).where(
            ReferralCommission.referrer_id == current_user.id, ReferralCommission.status == "pending"
        )
    )
    paid_cents = await db.scalar(
        select(func.coalesce(func.sum(ReferralCommission.commission_cents), 0)).where(
            ReferralCommission.referrer_id == current_user.id, ReferralCommission.status == "paid"
        )
    )
    return ReferralStatsOut(
        referral_code=current_user.referral_code,
        total_referrals=total or 0,
        paying_referrals=paying or 0,
        pending_commission_cents=pending_cents or 0,
        paid_commission_cents=paid_cents or 0,
    )
