"""
Authorization service layer -- this module IS the replacement for every Row Level
Security policy and enforcement trigger in the old schema. There is no database-level
fallback anymore: every router that touches devices/consents/location_pings/geofences/
watch_topics MUST call through here rather than querying the ORM directly, or the
authorization/plan-limit rules silently stop applying. This is a real trade-off vs
RLS -- see the top-level README's "What changed vs the Supabase version."

Each function below is commented with which Postgres policy/trigger it replaces.
"""
import uuid
from datetime import datetime, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ConflictError, ForbiddenError, NotFoundError, PlanLimitError
from app.models.consent import Consent, ConsentAuditLog
from app.models.device import Device
from app.models.user import User

FREE_MAX_OWN_DEVICES = 3  # 20260702121500_free_tier_devices.sql
FREE_MAX_ACTIVE_WATCHES = 2


# ---------- plan tier ----------
def effective_plan_tier(user: User) -> str:
    """Ports effective_plan_tier(uuid) -- a lapsed plan_renews_at means 'free'
    regardless of what plan_tier still says, so nobody keeps paid access forever after
    their last payment expired."""
    if user.plan_renews_at is not None and user.plan_renews_at < datetime.now(timezone.utc):
        return "free"
    return user.plan_tier


# ---------- device visibility (was devices_select_own / devices_select_consented) ----------
async def device_visibility(db: AsyncSession, viewer_id: uuid.UUID, device: Device) -> str | None:
    """Returns 'owner', 'precise', 'city', or None (not visible)."""
    if device.owner_id == viewer_id:
        return "owner"
    consent = await db.scalar(
        select(Consent).where(
            Consent.grantor_id == device.owner_id,
            Consent.grantee_id == viewer_id,
            Consent.status == "active",
        )
    )
    return consent.scope if consent else None


async def require_device_visible(db: AsyncSession, viewer_id: uuid.UUID, device: Device | None) -> str:
    if device is None:
        raise NotFoundError("Device not found.")
    precision = await device_visibility(db, viewer_id, device)
    if precision is None:
        raise ForbiddenError("Not authorized to view this device.")
    return precision


async def visible_device_ids(db: AsyncSession, viewer_id: uuid.UUID) -> dict[uuid.UUID, str]:
    """Bulk version used by GET /devices and the map endpoints -- was
    get_visible_device_locations()'s `visible` CTE."""
    owned_rows = (await db.execute(select(Device.id).where(Device.owner_id == viewer_id))).scalars().all()
    result: dict[uuid.UUID, str] = {d: "owner" for d in owned_rows}

    consented_rows = await db.execute(
        select(Device.id, Consent.scope)
        .join(Consent, Consent.grantor_id == Device.owner_id)
        .where(Consent.grantee_id == viewer_id, Consent.status == "active")
    )
    for device_id, scope in consented_rows.all():
        result.setdefault(device_id, scope)
    return result


# ---------- geofence write access (was geofences_write_owner + geofences_write_consented) ----------
async def can_write_geofence(db: AsyncSession, actor_id: uuid.UUID, device: Device) -> bool:
    if device.owner_id == actor_id:
        return True
    consent = await db.scalar(
        select(Consent.id).where(
            Consent.grantor_id == device.owner_id,
            Consent.grantee_id == actor_id,
            Consent.status == "active",
        )
    )
    return consent is not None


async def require_can_write_geofence(db: AsyncSession, actor_id: uuid.UUID, device: Device) -> None:
    if not await can_write_geofence(db, actor_id, device):
        raise ForbiddenError("Only the device owner or an active consent grantee can manage its geofences.")


# ---------- plan limits ----------
async def check_device_create_limit(db: AsyncSession, owner: User) -> None:
    """Was enforce_device_plan_limit() (free plan: 3 own devices)."""
    if effective_plan_tier(owner) != "free":
        return
    count = await db.scalar(select(func.count()).select_from(Device).where(Device.owner_id == owner.id))
    if (count or 0) >= FREE_MAX_OWN_DEVICES:
        raise PlanLimitError(
            f"Free plan is limited to {FREE_MAX_OWN_DEVICES} devices. Upgrade to Plus for unlimited devices."
        )


def check_precise_scope_allowed(requester: User) -> None:
    """Was enforce_consent_plan_limits()'s INSERT branch."""
    if effective_plan_tier(requester) == "free":
        raise PlanLimitError(
            "Precise location requires a Plus or Pro plan. Request city-level access instead, or upgrade."
        )


async def check_watch_limit_on_approve(db: AsyncSession, grantee: User, consent_id: uuid.UUID) -> None:
    """Was enforce_consent_plan_limits()'s pending->active UPDATE branch."""
    if effective_plan_tier(grantee) != "free":
        return
    count = await db.scalar(
        select(func.count())
        .select_from(Consent)
        .where(Consent.grantee_id == grantee.id, Consent.status == "active", Consent.id != consent_id)
    )
    if (count or 0) >= FREE_MAX_ACTIVE_WATCHES:
        raise PlanLimitError(
            f"Free plan is limited to watching {FREE_MAX_ACTIVE_WATCHES} people. "
            "The requester needs to upgrade to Plus before you can approve this."
        )


def check_geofence_create_limit(creator: User) -> None:
    """Was enforce_geofence_plan_limit()."""
    if effective_plan_tier(creator) == "free":
        raise PlanLimitError("Geofencing requires a Plus or Pro plan.")


def check_watch_topic_create_limit(owner: User) -> None:
    """Was enforce_watch_topic_plan_limit()."""
    if effective_plan_tier(owner) == "free":
        raise PlanLimitError(
            "The Intel watchlist requires a Plus or Pro plan. Free accounts can still read every headline."
        )


# ---------- consent lifecycle (was enforce_consent_transition() + log_consent_event()) ----------
async def _log_consent_event(
    db: AsyncSession, consent: Consent, actor_id: uuid.UUID, action: str, metadata: dict | None = None
) -> None:
    db.add(
        ConsentAuditLog(
            id=uuid.uuid4(),
            consent_id=consent.id,
            actor_id=actor_id,
            action=action,
            audit_metadata=metadata or {},
        )
    )


async def create_consent_request(
    db: AsyncSession,
    *,
    grantor_id: uuid.UUID,
    grantee: User,
    scope: str,
    expires_at: datetime | None,
) -> Consent:
    if grantor_id == grantee.id:
        raise ConflictError("You cannot request consent from yourself.")

    live = await db.scalar(
        select(Consent.id).where(
            Consent.grantor_id == grantor_id,
            Consent.grantee_id == grantee.id,
            Consent.status.in_(("pending", "active")),
        )
    )
    if live is not None:
        raise ConflictError("A pending or active request already exists for this person.")

    if scope == "precise":
        check_precise_scope_allowed(grantee)

    consent = Consent(
        id=uuid.uuid4(),
        grantor_id=grantor_id,
        grantee_id=grantee.id,
        status="pending",
        scope=scope,
        expires_at=expires_at,
    )
    db.add(consent)
    await db.flush()
    await _log_consent_event(db, consent, grantee.id, "requested", {"scope": scope, "expires_at": str(expires_at)})
    return consent


async def transition_consent(
    db: AsyncSession, consent: Consent, new_status: str, actor: User
) -> Consent:
    """Ports enforce_consent_transition()'s legality checks exactly, since there's no
    trigger doing this automatically anymore."""
    if consent.status == "pending" and new_status in ("active", "denied"):
        if actor.id != consent.grantor_id:
            raise ForbiddenError("Only the device owner can approve or deny a consent request.")
        if new_status == "active":
            grantee = await db.get(User, consent.grantee_id)
            await check_watch_limit_on_approve(db, grantee, consent.id)
        consent.status = new_status
        consent.responded_at = datetime.now(timezone.utc)
        await _log_consent_event(db, consent, actor.id, "approved" if new_status == "active" else "denied")

    elif consent.status == "active" and new_status == "revoked":
        if actor.id not in (consent.grantor_id, consent.grantee_id):
            raise ForbiddenError("Only a party to this consent can revoke it.")
        consent.status = "revoked"
        consent.revoked_at = datetime.now(timezone.utc)
        consent.revoked_by = actor.id
        await _log_consent_event(db, consent, actor.id, "revoked")

    else:
        raise ConflictError(f"Invalid consent status transition: {consent.status} -> {new_status}")

    await db.flush()
    return consent
