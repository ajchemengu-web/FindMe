import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class NewsItemOut(BaseModel):
    id: uuid.UUID
    source: str
    category: str
    headline: str
    summary: str | None
    url: str | None
    sentiment: float | None
    published_at: datetime
    ingested_at: datetime

    model_config = {"from_attributes": True}


class WatchTopicCreate(BaseModel):
    topic_type: Literal["region", "company", "keyword"]
    value: str = Field(min_length=1, max_length=64)


class WatchTopicOut(BaseModel):
    id: uuid.UUID
    owner_id: uuid.UUID
    topic_type: str
    value: str
    created_at: datetime

    model_config = {"from_attributes": True}
