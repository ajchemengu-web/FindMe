import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class GeofenceCreate(BaseModel):
    name: str = Field(min_length=1, max_length=64)
    lat: float = Field(ge=-90, le=90)
    lon: float = Field(ge=-180, le=180)
    radius_m: int = Field(gt=0)


class GeofenceUpdate(BaseModel):
    name: str | None = None
    active: bool | None = None


class GeofenceOut(BaseModel):
    id: uuid.UUID
    device_id: uuid.UUID
    created_by: uuid.UUID
    name: str
    lon: float
    lat: float
    radius_m: int
    active: bool
    created_at: datetime
