"""
End-to-end service-layer tests against a real Postgres+PostGIS database -- these
exercise the code paths that used to be covered by findme_backend's SQL RLS/trigger
test suite (findme_backend/test/, run via psql assertions). Skipped automatically
unless FINDME_TEST_DATABASE_URL is set; run with:

    docker compose up -d db
    FINDME_TEST_DATABASE_URL=postgresql+asyncpg://findme:findme@localhost:5432/findme_test \\
        pytest tests/test_integration_flows.py -v
"""
import uuid

import pytest

from app.core.errors import ConflictError, ForbiddenError, PlanLimitError
from app.models.consent import ConsentAuditLog
from app.models.device import Device
from app.models.geofence import GeofenceEvent
from app.models.location import LocationPing
from app.services import authz
from app.services.auth import authenticate, issue_token_pair, signup
from app.services.geo import lonlat_to_point
from app.services.geofence_eval import evaluate_geofences_for_ping
from sqlalchemy import select

pytestmark = pytest.mark.asyncio


async def _make_user(db_session, username, email=None, phone=None):
    return await signup(
        db_session, email=email or f"{username}@example.com", password="Str0ng&Secure!",
        username=username, phone=phone, display_name=username, referral_code=None,
    )


async def test_signup_and_authenticate(db_session):
    user = await _make_user(db_session, "alice")
    await db_session.commit()

    found = await authenticate(db_session, "alice", "Str0ng&Secure!")
    assert found.id == user.id

    with pytest.raises(Exception):
        await authenticate(db_session, "alice", "WrongPassword!")


async def test_referral_code_generated_and_linked(db_session):
    referrer = await _make_user(db_session, "referrer1")
    await db_session.commit()
    assert referrer.referral_code

    referred = await signup(
        db_session, email="referred1@example.com", password="Str0ng&Secure!",
        username="referred1", phone=None, display_name="referred1", referral_code=referrer.referral_code,
    )
    await db_session.commit()

    from app.models.referral import Referral

    row = await db_session.scalar(select(Referral).where(Referral.referred_id == referred.id))
    assert row is not None
    assert row.referrer_id == referrer.id


async def test_free_plan_device_limit(db_session):
    owner = await _make_user(db_session, "devowner")
    await db_session.commit()

    for i in range(authz.FREE_MAX_OWN_DEVICES):
        await authz.check_device_create_limit(db_session, owner)
        db_session.add(Device(id=uuid.uuid4(), owner_id=owner.id, nickname=f"phone{i}"))
        await db_session.commit()

    with pytest.raises(PlanLimitError):
        await authz.check_device_create_limit(db_session, owner)


async def test_consent_request_approve_creates_audit_trail(db_session):
    grantor = await _make_user(db_session, "grantor1")
    grantee = await _make_user(db_session, "grantee1")
    await db_session.commit()

    consent = await authz.create_consent_request(
        db_session, grantor_id=grantor.id, grantee=grantee, scope="city", expires_at=None
    )
    await db_session.commit()
    assert consent.status == "pending"

    # Grantee cannot approve their own request.
    with pytest.raises(ForbiddenError):
        await authz.transition_consent(db_session, consent, "active", grantee)

    approved = await authz.transition_consent(db_session, consent, "active", grantor)
    await db_session.commit()
    assert approved.status == "active"
    assert approved.responded_at is not None

    log_rows = (
        await db_session.execute(select(ConsentAuditLog).where(ConsentAuditLog.consent_id == consent.id))
    ).scalars().all()
    actions = sorted(r.action for r in log_rows)
    assert actions == ["approved", "requested"]


async def test_precise_scope_requires_paid_plan(db_session):
    grantor = await _make_user(db_session, "grantor2")
    grantee = await _make_user(db_session, "grantee2")  # stays on free plan
    await db_session.commit()

    with pytest.raises(PlanLimitError):
        await authz.create_consent_request(
            db_session, grantor_id=grantor.id, grantee=grantee, scope="precise", expires_at=None
        )


async def test_duplicate_live_consent_request_conflicts(db_session):
    grantor = await _make_user(db_session, "grantor3")
    grantee = await _make_user(db_session, "grantee3")
    await db_session.commit()

    await authz.create_consent_request(db_session, grantor_id=grantor.id, grantee=grantee, scope="city", expires_at=None)
    await db_session.commit()

    with pytest.raises(ConflictError):
        await authz.create_consent_request(db_session, grantor_id=grantor.id, grantee=grantee, scope="city", expires_at=None)


async def test_geofence_enter_and_exit_raises_alerts(db_session):
    from app.models.geofence import Geofence
    from app.models.alert import Alert

    owner = await _make_user(db_session, "geoowner")
    await db_session.commit()

    device = Device(id=uuid.uuid4(), owner_id=owner.id, nickname="Kid's Phone")
    db_session.add(device)
    await db_session.commit()

    # Nairobi CBD-ish center, 500m radius.
    geofence = Geofence(
        id=uuid.uuid4(), device_id=device.id, created_by=owner.id, name="School",
        center=lonlat_to_point(36.8219, -1.2921), radius_m=500,
    )
    db_session.add(geofence)
    await db_session.commit()

    # First ping: well outside the fence -- no prior ping, so this should NOT log an
    # 'enter' (was_inside defaults false, is_inside is also false here).
    far_ping = LocationPing(device_id=device.id, location=lonlat_to_point(36.90, -1.30))
    db_session.add(far_ping)
    await db_session.flush()
    await evaluate_geofences_for_ping(db_session, far_ping)
    await db_session.commit()

    events = (await db_session.execute(select(GeofenceEvent))).scalars().all()
    assert events == []

    # Second ping: inside the fence -- should log 'enter' + a warning alert.
    near_ping = LocationPing(device_id=device.id, location=lonlat_to_point(36.8220, -1.2922))
    db_session.add(near_ping)
    await db_session.flush()
    await evaluate_geofences_for_ping(db_session, near_ping)
    await db_session.commit()

    events = (await db_session.execute(select(GeofenceEvent))).scalars().all()
    assert len(events) == 1
    assert events[0].event_type == "enter"

    alerts = (await db_session.execute(select(Alert).where(Alert.owner_id == owner.id))).scalars().all()
    assert len(alerts) == 1
    assert alerts[0].category == "geofence"
    assert "entered School" in alerts[0].message

    # Third ping: back outside -- should log 'exit' + a good-severity alert.
    leave_ping = LocationPing(device_id=device.id, location=lonlat_to_point(36.90, -1.30))
    db_session.add(leave_ping)
    await db_session.flush()
    await evaluate_geofences_for_ping(db_session, leave_ping)
    await db_session.commit()

    events = (await db_session.execute(select(GeofenceEvent))).scalars().all()
    assert sorted(e.event_type for e in events) == ["enter", "exit"]
