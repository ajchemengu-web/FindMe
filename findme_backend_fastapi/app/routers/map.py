"""
/map -- ports 20260702121000_map_rpcs.sql's get_visible_device_locations() and
get_threat_zones_geo(). geofences_geo is served from /devices/{id}/geofences (already
plain lon/lat) rather than a separate endpoint -- no need for a second representation
here since this service was never limited by supabase-js's inability to parse a raw
PostGIS wire format the way the original RPC was.
"""
from fastapi import APIRouter
from sqlalchemy import select

from app.deps import CurrentUser, DbSession
from app.models.device import Device
from app.models.location import LocationPing
from app.models.threat import ThreatZone
from app.schemas.map import ThreatZoneGeoOut, VisibleDeviceLocationOut
from app.services import authz
from app.services.geo import point_to_lonlat, snap_to_grid

router = APIRouter(prefix="/map", tags=["map"])


@router.get("/devices", response_model=list[VisibleDeviceLocationOut])
async def visible_device_locations(current_user: CurrentUser, db: DbSession) -> list[VisibleDeviceLocationOut]:
    visible = await authz.visible_device_ids(db, current_user.id)
    if not visible:
        return []

    devices = (await db.execute(select(Device).where(Device.id.in_(visible.keys())))).scalars().all()
    out: list[VisibleDeviceLocationOut] = []
    for device in devices:
        latest = await db.scalar(
            select(LocationPing)
            .where(LocationPing.device_id == device.id)
            .order_by(LocationPing.recorded_at.desc())
            .limit(1)
        )
        if latest is None:
            continue
        precision = visible[device.id]
        lon, lat = point_to_lonlat(latest.location)
        if precision == "city":
            lon, lat = snap_to_grid(lon, lat)
        out.append(
            VisibleDeviceLocationOut(
                device_id=device.id, nickname=device.nickname, lon=lon, lat=lat,
                recorded_at=latest.recorded_at, precision_level=precision,
            )
        )
    return out


@router.get("/threat-zones", response_model=list[ThreatZoneGeoOut])
async def threat_zones_geo(current_user: CurrentUser, db: DbSession) -> list[ThreatZoneGeoOut]:
    """Public reference data -- any authenticated user, same as threat_zones_select_authenticated."""
    zones = (await db.execute(select(ThreatZone))).scalars().all()
    out = []
    for z in zones:
        lon, lat = point_to_lonlat(z.location)
        out.append(
            ThreatZoneGeoOut(
                id=z.id, category=z.category, severity=z.severity, title=z.title, summary=z.summary,
                source=z.source, lon=lon, lat=lat, radius_km=z.radius_km, event_date=z.event_date,
            )
        )
    return out
