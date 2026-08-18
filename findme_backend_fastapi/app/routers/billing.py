"""
/billing -- M-Pesa STK Push + Safaricom's callback, plus a plan-status endpoint that
mirrors findme_app/lib/billing.ts's client-side featuresForTier()/fetchOwnDeviceCount()/
fetchActiveWatchCount() (now computed server-side, which is the more honest place for
"how many devices do you have left" to live anyway).
"""
import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Request, status
from sqlalchemy import func, select

from app.core.errors import ForbiddenError, NotFoundError
from app.deps import CurrentUser, DbSession
from app.models.consent import Consent
from app.models.device import Device
from app.models.mpesa import MpesaTransaction
from app.models.referral import Referral, ReferralCommission
from app.models.user import User
from app.schemas.billing import (
    BillingStatusOut,
    MpesaTransactionOut,
    PlanFeatures,
    StkPushRequest,
    StkPushResponse,
)
from app.services import authz
from app.services.mpesa import KES_PRICE, PASS_DURATION_DAYS, REFERRAL_COMMISSION_RATE, MpesaError, initiate_stk_push
from app.services.phone import normalize_kenyan_msisdn

router = APIRouter(prefix="/billing", tags=["billing"])


def _features_for_tier(tier: str) -> PlanFeatures:
    """Ports featuresForTier() from findme_app/lib/billing.ts."""
    if tier == "free":
        return PlanFeatures(
            max_own_devices=authz.FREE_MAX_OWN_DEVICES,
            max_active_watches=authz.FREE_MAX_ACTIVE_WATCHES,
            geofencing_allowed=False,
            precise_scope_allowed=False,
            intel_watchlist_allowed=False,
        )
    return PlanFeatures(
        max_own_devices=None, max_active_watches=None,
        geofencing_allowed=True, precise_scope_allowed=True, intel_watchlist_allowed=True,
    )


@router.get("/status", response_model=BillingStatusOut)
async def billing_status(current_user: CurrentUser, db: DbSession) -> BillingStatusOut:
    effective = authz.effective_plan_tier(current_user)
    own_devices = await db.scalar(select(func.count()).select_from(Device).where(Device.owner_id == current_user.id))
    active_watches = await db.scalar(
        select(func.count()).select_from(Consent).where(Consent.grantee_id == current_user.id, Consent.status == "active")
    )
    return BillingStatusOut(
        plan_tier=current_user.plan_tier,
        effective_plan_tier=effective,
        plan_renews_at=current_user.plan_renews_at,
        own_device_count=own_devices or 0,
        active_watch_count=active_watches or 0,
        features=_features_for_tier(effective),
    )


@router.post("/mpesa/stk-push", response_model=StkPushResponse, status_code=status.HTTP_201_CREATED)
async def mpesa_stk_push(payload: StkPushRequest, current_user: CurrentUser, db: DbSession) -> StkPushResponse:
    msisdn = normalize_kenyan_msisdn(payload.phone)
    if msisdn is None:
        raise ForbiddenError("Enter a valid Kenyan phone number (e.g. 07XX XXX XXX).")

    try:
        stk = await initiate_stk_push(payload.tier, msisdn)
    except MpesaError as exc:
        raise ForbiddenError(str(exc))

    txn = MpesaTransaction(
        id=uuid.uuid4(),
        user_id=current_user.id,
        tier=payload.tier,
        amount_kes=KES_PRICE[payload.tier],
        phone=msisdn,
        checkout_request_id=stk["CheckoutRequestID"],
        merchant_request_id=stk.get("MerchantRequestID"),
    )
    db.add(txn)
    await db.commit()
    await db.refresh(txn)
    return StkPushResponse(transaction_id=txn.id, checkout_request_id=txn.checkout_request_id)


@router.get("/mpesa/transactions/{transaction_id}", response_model=MpesaTransactionOut)
async def get_mpesa_transaction(transaction_id: uuid.UUID, current_user: CurrentUser, db: DbSession) -> MpesaTransactionOut:
    txn = await db.get(MpesaTransaction, transaction_id)
    if txn is None:
        raise NotFoundError("Transaction not found.")
    if txn.user_id != current_user.id:
        raise ForbiddenError("Not your transaction.")
    return MpesaTransactionOut.model_validate(txn)


@router.post("/mpesa/callback")
async def mpesa_callback(request: Request, db: DbSession) -> dict:
    """Deployed with NO auth requirement -- Safaricom calls this directly and has no
    session. Ports mpesa-stk-callback/index.ts exactly, including its "always
    acknowledge, even on our own internal error" behavior (Daraja retries callbacks
    that don't get a fast 200). See this project's README for the known gap this
    inherits unchanged: the only real protection on this endpoint is that its URL was
    never shown to the customer, only sent to Safaricom in the STK Push request."""
    try:
        body = await request.json()
        callback = body["Body"]["stkCallback"]
        checkout_request_id = callback["CheckoutRequestID"]
    except (KeyError, ValueError):
        return {"ResultCode": 0, "ResultDesc": "Accepted"}

    txn = await db.scalar(select(MpesaTransaction).where(MpesaTransaction.checkout_request_id == checkout_request_id))
    if txn is None or txn.status != "pending":
        # No matching transaction, or already resolved (a redelivered callback) --
        # acknowledge without redoing the write.
        return {"ResultCode": 0, "ResultDesc": "Accepted"}

    result_code = callback.get("ResultCode")
    now = datetime.now(timezone.utc)

    if result_code == 0:
        items = {i["Name"]: i.get("Value") for i in callback.get("CallbackMetadata", {}).get("Item", [])}
        txn.status = "success"
        txn.mpesa_receipt_number = str(items.get("MpesaReceiptNumber")) if items.get("MpesaReceiptNumber") else None
        txn.result_desc = callback.get("ResultDesc")
        txn.completed_at = now

        user = await db.get(User, txn.user_id)
        user.plan_tier = txn.tier
        user.plan_renews_at = now + timedelta(days=PASS_DURATION_DAYS)

        referral = await db.scalar(select(Referral).where(Referral.referred_id == txn.user_id))
        if referral is not None:
            existing_commission = await db.scalar(
                select(ReferralCommission.id).where(ReferralCommission.referral_id == referral.id)
            )
            if existing_commission is None:
                amount_paid_cents = round(float(items.get("Amount", txn.amount_kes)) * 100)
                commission_cents = round(amount_paid_cents * REFERRAL_COMMISSION_RATE)
                db.add(
                    ReferralCommission(
                        id=uuid.uuid4(), referral_id=referral.id, referrer_id=referral.referrer_id,
                        referred_id=txn.user_id, plan_tier=txn.tier,
                        amount_paid_cents=amount_paid_cents, commission_cents=commission_cents,
                    )
                )
    else:
        txn.status = "failed"
        txn.result_desc = callback.get("ResultDesc")
        txn.completed_at = now

    await db.commit()
    return {"ResultCode": 0, "ResultDesc": "Accepted"}
