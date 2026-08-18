import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel


class StkPushRequest(BaseModel):
    tier: Literal["plus", "pro"]
    phone: str


class StkPushResponse(BaseModel):
    transaction_id: uuid.UUID
    checkout_request_id: str


class MpesaTransactionOut(BaseModel):
    id: uuid.UUID
    tier: str
    amount_kes: int
    phone: str
    status: str
    mpesa_receipt_number: str | None
    created_at: datetime
    completed_at: datetime | None

    model_config = {"from_attributes": True}


class PlanFeatures(BaseModel):
    max_own_devices: int | None
    max_active_watches: int | None
    geofencing_allowed: bool
    precise_scope_allowed: bool
    intel_watchlist_allowed: bool
    priority_alerts_allowed: bool = False  # honestly unimplemented on every tier -- see README


class BillingStatusOut(BaseModel):
    plan_tier: str
    effective_plan_tier: str
    plan_renews_at: datetime | None
    own_device_count: int
    active_watch_count: int
    features: PlanFeatures
