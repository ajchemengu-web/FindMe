"""
Geofence enter/exit evaluation -- ports evaluate_geofences_for_ping(bigint) from
20260702120900_geofence_evaluation.sql. Called synchronously right after a location
ping insert commits (app/routers/devices.py), instead of via a Database Webhook +
geofence-evaluate Edge Function round trip -- one process, no HTTP hop, same net
effect. Distance math is still delegated to PostGIS's ST_DWithin (geodesic, on the
geography type) rather than reimplemented in Python, for the same reason the original
kept it in SQL: correctness near the poles / antimeridian that a naive Python haversine
would get subtly wrong.
"""
import uuid

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.alert import Alert
from app.models.device import Device
from app.models.geofence import Geofence, GeofenceEvent
from app.models.location import LocationPing
from app.services.push import notify_user


async def _is_within(db: AsyncSession, location, center, radius_m: int) -> bool:
    return bool(await db.scalar(select(func.ST_DWithin(location, center, radius_m))))


async def evaluate_geofences_for_ping(db: AsyncSession, ping: LocationPing) -> None:
    device = await db.get(Device, ping.device_id)
    if device is None:
        return  # ping's device vanished mid-request -- don't error the caller over a race

    geofences = (
        (await db.execute(select(Geofence).where(Geofence.device_id == ping.device_id, Geofence.active.is_(True))))
        .scalars()
        .all()
    )
    if not geofences:
        return

    # "was inside" = the most recent ping for this device at-or-before this one,
    # excluding this ping itself. No prior ping counts as "was not inside", so a
    # device's very first ping landing inside a fence still logs an 'enter'.
    prev_ping = await db.scalar(
        select(LocationPing)
        .where(
            LocationPing.device_id == ping.device_id,
            LocationPing.id != ping.id,
            LocationPing.recorded_at <= ping.recorded_at,
        )
        .order_by(LocationPing.recorded_at.desc())
        .limit(1)
    )

    for g in geofences:
        is_inside = await _is_within(db, ping.location, g.center, g.radius_m)
        was_inside = await _is_within(db, prev_ping.location, g.center, g.radius_m) if prev_ping else False

        if is_inside and not was_inside:
            db.add(
                GeofenceEvent(
                    geofence_id=g.id, device_id=ping.device_id, event_type="enter", occurred_at=ping.recorded_at
                )
            )
            db.add(
                Alert(
                    id=uuid.uuid4(),
                    owner_id=device.owner_id,
                    severity="warning",
                    category="geofence",
                    message=f"{device.nickname} entered {g.name}",
                    related_device_id=device.id,
                )
            )
            await notify_user(
                db, device.owner_id, "Geofence alert", f"{device.nickname} entered {g.name}",
                {"deviceId": str(device.id), "geofenceId": str(g.id), "type": "geofence"},
            )
        elif (not is_inside) and was_inside:
            db.add(
                GeofenceEvent(
                    geofence_id=g.id, device_id=ping.device_id, event_type="exit", occurred_at=ping.recorded_at
                )
            )
            db.add(
                Alert(
                    id=uuid.uuid4(),
                    owner_id=device.owner_id,
                    severity="good",
                    category="geofence",
                    message=f"{device.nickname} left {g.name}",
                    related_device_id=device.id,
                )
            )
            await notify_user(
                db, device.owner_id, "Geofence alert", f"{device.nickname} left {g.name}",
                {"deviceId": str(device.id), "geofenceId": str(g.id), "type": "geofence"},
            )

    await db.flush()
