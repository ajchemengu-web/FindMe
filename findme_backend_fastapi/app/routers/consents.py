"""
/consents -- the consent ledger. Ports 20260702120200_consents.sql's policies +
enforce_consent_transition()/log_consent_event() triggers (now
app/services/authz.py's create_consent_request()/transition_consent()), plus
consent-notify/index.ts's push-notification side effects.
"""
import uuid

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import or_, select

from app.core.errors import AppError, ForbiddenError, NotFoundError
from app.deps import CurrentUser, DbSession
from app.models.consent import Consent, ConsentAuditLog
from app.models.user import User
from app.schemas.consent import (
    ConsentAuditLogOut,
    ConsentCreate,
    ConsentOut,
    ConsentRespond,
    InviteRequest,
    InviteResponse,
    MyConsentsOut,
)
from app.services import authz, invites
from app.services.push import notify_user

router = APIRouter(prefix="/consents", tags=["consents"])


@router.get("", response_model=MyConsentsOut)
async def list_my_consents(current_user: CurrentUser, db: DbSession) -> MyConsentsOut:
    """Ports fetchMyConsents()'s grouping -- was consents_select_party's RLS policy
    plus client-side filtering into incoming/outgoingPending/active."""
    rows = (
        (
            await db.execute(
                select(Consent)
                .where(or_(Consent.grantor_id == current_user.id, Consent.grantee_id == current_user.id))
                .order_by(Consent.created_at.desc())
            )
        )
        .scalars()
        .all()
    )
    incoming = [c for c in rows if c.grantor_id == current_user.id and c.status == "pending"]
    outgoing_pending = [c for c in rows if c.grantee_id == current_user.id and c.status == "pending"]
    active = [c for c in rows if c.status == "active"]
    return MyConsentsOut(
        incoming=[ConsentOut.model_validate(c) for c in incoming],
        outgoing_pending=[ConsentOut.model_validate(c) for c in outgoing_pending],
        active=[ConsentOut.model_validate(c) for c in active],
    )


@router.post("", response_model=ConsentOut, status_code=status.HTTP_201_CREATED)
async def request_consent(payload: ConsentCreate, current_user: CurrentUser, db: DbSession) -> ConsentOut:
    """"I (the signed-in user) want to see grantorId's location" -- was
    consents_insert_as_requester + enforce_consent_plan_limits()'s INSERT branch."""
    grantor = await db.get(User, payload.grantor_id)
    if grantor is None:
        raise NotFoundError("No account found for that person.")

    consent = await authz.create_consent_request(
        db, grantor_id=payload.grantor_id, grantee=current_user, scope=payload.scope, expires_at=payload.expires_at
    )
    await db.commit()
    await db.refresh(consent)

    await notify_user(
        db, grantor.id, "New watch-list request",
        "Someone wants to add your device to their watch list. Review and respond.",
        {"consentId": str(consent.id), "type": "consent"},
    )
    await db.commit()
    return ConsentOut.model_validate(consent)


@router.post("/invite", response_model=InviteResponse, status_code=status.HTTP_201_CREATED)
async def invite_or_request(payload: InviteRequest, current_user: CurrentUser, db: DbSession) -> InviteResponse:
    """"Someone else" step of Add to Watch List, for a phone number that may or may not
    have a FindMe account yet. Ports app/services/invites.py's find-or-invite logic --
    new capability, no Supabase-era equivalent (the original app could only target an
    existing account via GET /auth/lookup + POST /consents)."""
    if "@" in payload.contact:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Email invites aren't supported yet -- invite by phone number instead.")

    try:
        status_str, existing = await invites.invite_or_request(db, inviter=current_user, contact=payload.contact, scope=payload.scope)
        await db.commit()
    except AppError as exc:
        await db.rollback()
        raise HTTPException(exc.status_code, exc.message)

    if status_str == "requested" and existing is not None:
        await notify_user(
            db, existing.id, "New watch-list request",
            "Someone wants to add your device to their watch list. Review and respond.",
            {"type": "consent"},
        )
        await db.commit()
        return InviteResponse(status="requested", display_name=existing.display_name or existing.username)

    return InviteResponse(status="invited")


@router.patch("/{consent_id}", response_model=ConsentOut)
async def respond_to_request(
    consent_id: uuid.UUID, payload: ConsentRespond, current_user: CurrentUser, db: DbSession
) -> ConsentOut:
    """Approve or deny a pending request -- grantor only."""
    consent = await db.get(Consent, consent_id)
    if consent is None:
        raise NotFoundError("Consent request not found.")

    consent = await authz.transition_consent(db, consent, payload.status, current_user)
    await db.commit()
    await db.refresh(consent)

    if payload.status == "active":
        await notify_user(
            db, consent.grantee_id, "Request approved",
            "Your consent request was approved -- their location is now visible.",
            {"consentId": str(consent.id), "type": "consent"},
        )
    else:
        await notify_user(
            db, consent.grantee_id, "Request denied", "Your consent request was not approved.",
            {"consentId": str(consent.id), "type": "consent"},
        )
    await db.commit()
    return ConsentOut.model_validate(consent)


@router.post("/{consent_id}/revoke", response_model=ConsentOut)
async def revoke_consent(consent_id: uuid.UUID, current_user: CurrentUser, db: DbSession) -> ConsentOut:
    """Either party may revoke an active grant."""
    consent = await db.get(Consent, consent_id)
    if consent is None:
        raise NotFoundError("Consent not found.")

    consent = await authz.transition_consent(db, consent, "revoked", current_user)
    await db.commit()
    await db.refresh(consent)

    # TODO (ported as-is from consent-notify's own TODO): notify whichever party did
    # NOT do the revoking, rather than always the grantor -- the original webhook
    # payload didn't expose revoked_by to the notifier either.
    await notify_user(
        db, consent.grantor_id, "Sharing stopped",
        "A location-sharing relationship on your watch list was revoked.",
        {"consentId": str(consent.id), "type": "consent"},
    )
    await db.commit()
    return ConsentOut.model_validate(consent)


@router.get("/{consent_id}/audit-log", response_model=list[ConsentAuditLogOut])
async def get_consent_audit_log(consent_id: uuid.UUID, current_user: CurrentUser, db: DbSession) -> list[ConsentAuditLogOut]:
    consent = await db.get(Consent, consent_id)
    if consent is None:
        raise NotFoundError("Consent not found.")
    if current_user.id not in (consent.grantor_id, consent.grantee_id):
        raise ForbiddenError("Not a party to this consent.")

    rows = (
        (
            await db.execute(
                select(ConsentAuditLog)
                .where(ConsentAuditLog.consent_id == consent_id)
                .order_by(ConsentAuditLog.created_at.asc())
            )
        )
        .scalars()
        .all()
    )
    return [
        ConsentAuditLogOut(
            id=r.id, consent_id=r.consent_id, actor_id=r.actor_id, action=r.action,
            metadata=r.audit_metadata, created_at=r.created_at,
        )
        for r in rows
    ]
