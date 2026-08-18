"""
/devices -- CRUD + location ping ingestion. Replaces the `devices` and `location_pings`
PostgREST tables plus get_device_locations()/evaluate_geofences_for_ping().
"""
import uuid

from fastapi import APIRouter, status
from sqlalchemy import select

from app.core.errors import ForbiddenError, NotFoundError
from app.deps import CurrentUser, DbSession
from app.models.device import Device
from app.models.location import LocationPing
from app.schemas.device import DeviceCreate, DeviceOut, DeviceUpdate, LocationOut, LocationPingCreate
from app.services import authz
from app.services.geo import lonlat_to_point, point_to_lonlat, snap_to_grid
from app.services.geofence_eval import evaluate_geofences_for_ping

router = APIRouter(prefix="/devices", tags=["devices"])


async def _device_out(db, device: Device, viewer_id: uuid.UUID) -> DeviceOut:
    precision = await authz.device_visibility(db, viewer_id, device)
    return DeviceOut(
        id=device.id,
        owner_id=device.owner_id,
        nickname=device.nickname,
        device_type=device.device_type,
        platform=device.platform,
        is_self_owned=device.is_self_owned,
        battery_pct=device.battery_pct,
        last_seen_at=device.last_seen_at,
        created_at=device.created_at,
        updated_at=device.updated_at,
        visibility=precision or "none",
    )


@router.get("", response_model=list[DeviceOut])
async def list_devices(current_user: CurrentUser, db: DbSession) -> list[DeviceOut]:
    """Was devices_select_own + devices_select_consented combined -- your own devices
    plus anyone who's granted you an active consent."""
    visible_ids = await authz.visible_device_ids(db, current_user.id)
    if not visible_ids:
        return []
    devices = (await db.execute(select(Device).where(Device.id.in_(visible_ids.keys())))).scalars().all()
    devices.sort(key=lambda d: d.created_at)
    return [
        DeviceOut(
            id=d.id, owner_id=d.owner_id, nickname=d.nickname, device_type=d.device_type,
            platform=d.platform, is_self_owned=d.is_self_owned, battery_pct=d.battery_pct,
            last_seen_at=d.last_seen_at, created_at=d.created_at, updated_at=d.updated_at,
            visibility=visible_ids[d.id],
        )
        for d in devices
    ]


@router.post("", response_model=DeviceOut, status_code=status.HTTP_201_CREATED)
async def create_device(payload: DeviceCreate, current_user: CurrentUser, db: DbSession) -> DeviceOut:
    await authz.check_device_create_limit(db, current_user)
    device = Device(
        id=uuid.uuid4(),
        owner_id=current_user.id,
        nickname=payload.nickname,
        device_type=payload.device_type,
        platform=payload.platform,
        is_self_owned=payload.is_self_owned,
        push_token=payload.push_token,
    )
    db.add(device)
    await db.commit()
    await db.refresh(device)
    return await _device_out(db, device, current_user.id)


@router.patch("/{device_id}", response_model=DeviceOut)
async def update_device(device_id: uuid.UUID, payload: DeviceUpdate, current_user: CurrentUser, db: DbSession) -> DeviceOut:
    device = await db.get(Device, device_id)
    if device is None:
        raise NotFoundError("Device not found.")
    if device.owner_id != current_user.id:
        raise ForbiddenError("Only the device owner can update it.")

    for field in ("nickname", "device_type", "platform", "push_token", "battery_pct"):
        value = getattr(payload, field)
        if value is not None:
            setattr(device, field, value)
    await db.commit()
    await db.refresh(device)
    return await _device_out(db, device, current_user.id)


@router.delete("/{device_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_device(device_id: uuid.UUID, current_user: CurrentUser, db: DbSession) -> None:
    device = await db.get(Device, device_id)
    if device is None:
        raise NotFoundError("Device not found.")
    if device.owner_id != current_user.id:
        raise ForbiddenError("Only the device owner can delete it.")
    await db.delete(device)
    await db.commit()


@router.post("/{device_id}/pings", response_model=LocationOut, status_code=status.HTTP_201_CREATED)
async def report_location(
    device_id: uuid.UUID, payload: LocationPingCreate, current_user: CurrentUser, db: DbSession
) -> LocationOut:
    """Was location_pings_insert_own_device -- only a device's own owner can write a
    ping for it. Runs evaluate_geofences_for_ping() synchronously afterward (was a
    Database Webhook to geofence-evaluate)."""
    device = await db.get(Device, device_id)
    if device is None:
        raise NotFoundError("Device not found.")
    if device.owner_id != current_user.id:
        raise ForbiddenError("Only a device's own owner can report its location.")

    ping = LocationPing(
        device_id=device_id,
        location=lonlat_to_point(payload.lon, payload.lat),
        accuracy_m=payload.accuracy_m,
        battery_pct=payload.battery_pct,
    )
    if payload.recorded_at is not None:
        ping.recorded_at = payload.recorded_at
    db.add(ping)
    await db.flush()

    device.last_seen_at = ping.recorded_at
    if payload.battery_pct is not None:
        device.battery_pct = payload.battery_pct

    await evaluate_geofences_for_ping(db, ping)
    await db.commit()

    return LocationOut(
        recorded_at=ping.recorded_at, lon=payload.lon, lat=payload.lat,
        accuracy_m=ping.accuracy_m, battery_pct=ping.battery_pct, precision_level="owner",
    )


@router.get("/{device_id}/locations", response_model=list[LocationOut])
async def get_device_locations(device_id: uuid.UUID, current_user: CurrentUser, db: DbSession, limit: int = 50) -> list[LocationOut]:
    """Ports get_device_locations(p_device_id, p_limit) -- coarsens to a ~5km grid for
    city-scope viewers, full precision for the owner or a precise-scope grantee."""
    device = await db.get(Device, device_id)
    precision = await authz.require_device_visible(db, current_user.id, device)

    capped_limit = min(limit, 500)
    pings = (
        (
            await db.execute(
                select(LocationPing)
                .where(LocationPing.device_id == device_id)
                .order_by(LocationPing.recorded_at.desc())
                .limit(capped_limit)
            )
        )
        .scalars()
        .all()
    )

    out: list[LocationOut] = []
    is_precise = precision in ("owner", "precise")
    for p in pings:
        lon, lat = point_to_lonlat(p.location)
        if not is_precise:
            lon, lat = snap_to_grid(lon, lat)
        out.append(
            LocationOut(
                recorded_at=p.recorded_at, lon=lon, lat=lat,
                accuracy_m=p.accuracy_m if is_precise else None,
                battery_pct=p.battery_pct, precision_level=precision,
            )
        )
    return out
