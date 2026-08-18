import uuid
from datetime import datetime

from pydantic import BaseModel


class AlertOut(BaseModel):
    id: uuid.UUID
    owner_id: uuid.UUID
    severity: str
    category: str
    message: str
    related_device_id: uuid.UUID | None
    related_threat_id: uuid.UUID | None
    read: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class AlertUpdate(BaseModel):
    read: bool
