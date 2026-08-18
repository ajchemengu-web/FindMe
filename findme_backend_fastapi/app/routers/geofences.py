"""
/devices/{device_id}/geofences + /geofences/{id} -- ports 20260702120500_geofences.sql
and 20260702120900_geofence_evaluation.sql's write-access fix (owner OR active-consent
grantee can manage a device's geofences, not just view them).
"""
import uuid

from fastapi import APIRouter, status
from sqlalchemy import select

from app.core.errors import NotFoundError
from app.deps import CurrentUser, DbSession
from app.models.device import Device
from app.models.geofence import Geofence
from app.schemas.geofence import GeofenceCreate, GeofenceOut, GeofenceUpdate
from app.services import authz
from app.services.geo import lonlat_to_point, point_to_lonlat

router = APIRouter(tags=["geofences"])


def _out(g: Geofence) -> GeofenceOut:
    lon, lat = point_to_lonlat(g.center)
    return GeofenceOut(
        id=g.id, device_id=g.device_id, created_by=g.created_by, name=g.name,
        lon=lon, lat=lat, radius_m=g.radius_m, active=g.active, created_at=g.created_at,
    )


@router.get("/devices/{device_id}/geofences", response_model=list[GeofenceOut])
async def list_geofences(device_id: uuid.UUID, current_user: CurrentUser, db: DbSession) -> list[GeofenceOut]:
    device = await db.get(Device, device_id)
    await authz.require_device_visible(db, current_user.id, device)
    geofences = (await db.execute(select(Geofence).where(Geofence.device_id == device_id))).scalars().all()
    return [_out(g) for g in geofences]


@router.post(
    "/devices/{device_id}/geofences", response_model=GeofenceOut, status_code=status.HTTP_201_CREATED
)
async def create_geofence(
    device_id: uuid.UUID, payload: GeofenceCreate, current_user: CurrentUser, db: DbSession
) -> GeofenceOut:
    device = await db.get(Device, device_id)
    if device is None:
        raise NotFoundError("Device not found.")
    await authz.require_can_write_geofence(db, current_user.id, device)
    authz.check_geofence_create_limit(current_user)

    geofence = Geofence(
        id=uuid.uuid4(), device_id=device_id, created_by=current_user.id, name=payload.name,
        center=lonlat_to_point(payload.lon, payload.lat), radius_m=payload.radius_m,
    )
    db.add(geofence)
    await db.commit()
    await db.refresh(geofence)
    return _out(geofence)


@router.patch("/geofences/{geofence_id}", response_model=GeofenceOut)
async def update_geofence(
    geofence_id: uuid.UUID, payload: GeofenceUpdate, current_user: CurrentUser, db: DbSession
) -> GeofenceOut:
    geofence = await db.get(Geofence, geofence_id)
    if geofence is None:
        raise NotFoundError("Geofence not found.")
    device = await db.get(Device, geofence.device_id)
    await authz.require_can_write_geofence(db, current_user.id, device)

    if payload.name is not None:
        geofence.name = payload.name
    if payload.active is not None:
        geofence.active = payload.active
    await db.commit()
    await db.refresh(geofence)
    return _out(geofence)


@router.delete("/geofences/{geofence_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_geofence(geofence_id: uuid.UUID, current_user: CurrentUser, db: DbSession) -> None:
    geofence = await db.get(Geofence, geofence_id)
    if geofence is None:
        raise NotFoundError("Geofence not found.")
    device = await db.get(Device, geofence.device_id)
    await authz.require_can_write_geofence(db, current_user.id, device)
    await db.delete(geofence)
    await db.commit()
