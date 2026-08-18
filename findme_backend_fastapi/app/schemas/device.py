import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class DeviceCreate(BaseModel):
    nickname: str = Field(min_length=1, max_length=64)
    device_type: str = "phone"
    platform: str | None = None
    is_self_owned: bool = True
    push_token: str | None = None


class DeviceUpdate(BaseModel):
    nickname: str | None = None
    device_type: str | None = None
    platform: str | None = None
    push_token: str | None = None
    battery_pct: int | None = None


class DeviceOut(BaseModel):
    id: uuid.UUID
    owner_id: uuid.UUID
    nickname: str
    device_type: str
    platform: str | None
    is_self_owned: bool
    battery_pct: int | None
    last_seen_at: datetime | None
    created_at: datetime
    updated_at: datetime
    # 'owner' | 'precise' | 'city' -- was implicit in which RLS policy matched;
    # returned explicitly now since there's no policy to infer it from.
    visibility: str

    model_config = {"from_attributes": True}


class LocationPingCreate(BaseModel):
    lat: float = Field(ge=-90, le=90)
    lon: float = Field(ge=-180, le=180)
    accuracy_m: float | None = None
    battery_pct: int | None = Field(default=None, ge=0, le=100)
    recorded_at: datetime | None = None


class LocationOut(BaseModel):
    recorded_at: datetime
    lon: float
    lat: float
    accuracy_m: float | None
    battery_pct: int | None
    precision_level: str
