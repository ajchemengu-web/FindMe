from datetime import date, datetime
import uuid

from pydantic import BaseModel


class VisibleDeviceLocationOut(BaseModel):
    device_id: uuid.UUID
    nickname: str
    lon: float
    lat: float
    recorded_at: datetime
    precision_level: str


class ThreatZoneGeoOut(BaseModel):
    id: uuid.UUID
    category: str
    severity: str
    title: str
    summary: str | None
    source: str
    lon: float
    lat: float
    radius_km: float | None
    event_date: date | None
