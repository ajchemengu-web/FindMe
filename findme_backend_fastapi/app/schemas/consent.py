import uuid
from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel


class ConsentCreate(BaseModel):
    grantor_id: uuid.UUID
    scope: Literal["precise", "city"] = "precise"
    expires_at: datetime | None = None


class ConsentRespond(BaseModel):
    status: Literal["active", "denied"]


class InviteRequest(BaseModel):
    # A phone number -- see routers/consents.py's /invite for why email isn't accepted
    # yet (no email-sending capability exists in this service).
    contact: str
    scope: Literal["precise", "city"] = "precise"


class InviteResponse(BaseModel):
    # "requested": contact already had an account, a real Consent row was created
    # immediately (identical to POST /consents). "invited": no account existed yet, an
    # SMS invite was sent and the request will be created automatically when they sign
    # up with this phone number.
    status: Literal["requested", "invited"]
    display_name: str | None = None


class ConsentOut(BaseModel):
    id: uuid.UUID
    grantor_id: uuid.UUID
    grantee_id: uuid.UUID
    status: str
    scope: str
    expires_at: datetime | None
    requested_at: datetime
    responded_at: datetime | None
    revoked_at: datetime | None
    revoked_by: uuid.UUID | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class MyConsentsOut(BaseModel):
    incoming: list[ConsentOut]
    outgoing_pending: list[ConsentOut]
    active: list[ConsentOut]


class ConsentAuditLogOut(BaseModel):
    id: uuid.UUID
    consent_id: uuid.UUID
    actor_id: uuid.UUID
    action: str
    metadata: dict[str, Any]
    created_at: datetime
