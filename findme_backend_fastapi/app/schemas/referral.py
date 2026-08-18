from pydantic import BaseModel


class ReferralStatsOut(BaseModel):
    referral_code: str
    total_referrals: int
    paying_referrals: int
    pending_commission_cents: int
    paid_commission_cents: int
