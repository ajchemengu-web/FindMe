"""threat_zones / news_items -- ported from 20260702120600_threat_intel.sql. Public
reference data; readable by any authenticated user, written only via the
cron-secret-gated /ingest/* endpoints (app/routers/ingest.py, replacing the
service-role-only Edge Functions ingest-conflict-events/ingest-news)."""
import uuid
from datetime import date, datetime
from typing import Any

from geoalchemy2 import Geography
from sqlalchemy import CheckConstraint, Date, DateTime, Float, Index, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class ThreatZone(Base):
    __tablename__ = "threat_zones"
    __table_args__ = (
        CheckConstraint("category in ('conflict','unrest','disaster')", name="threat_zones_category_check"),
        CheckConstraint("severity in ('warning','serious','critical')", name="threat_zones_severity_check"),
        UniqueConstraint("source", "external_id", name="threat_zones_source_external_idx"),
        Index("threat_zones_geo_idx", "location", postgresql_using="gist"),
        Index("threat_zones_category_idx", "category", "severity"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    external_id: Mapped[str | None] = mapped_column(String)
    source: Mapped[str] = mapped_column(String, nullable=False)
    category: Mapped[str] = mapped_column(String, nullable=False)
    severity: Mapped[str] = mapped_column(String, nullable=False)
    title: Mapped[str] = mapped_column(String, nullable=False)
    summary: Mapped[str | None] = mapped_column(String)
    location: Mapped[str] = mapped_column(Geography(geometry_type="POINT", srid=4326), nullable=False)
    radius_km: Mapped[float | None] = mapped_column(Float)
    event_date: Mapped[date | None] = mapped_column(Date)
    raw: Mapped[dict[str, Any]] = mapped_column(JSONB, nullable=False, default=dict)
    ingested_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default="now()", nullable=False)


class NewsItem(Base):
    __tablename__ = "news_items"
    __table_args__ = (
        CheckConstraint(
            "category in ('politics','business','markets','security')", name="news_items_category_check"
        ),
        CheckConstraint("sentiment between -1 and 1", name="news_items_sentiment_check"),
        Index("news_items_published_idx", "published_at"),
        Index("news_items_category_idx", "category"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    source: Mapped[str] = mapped_column(String, nullable=False)
    category: Mapped[str] = mapped_column(String, nullable=False)
    headline: Mapped[str] = mapped_column(String, nullable=False)
    summary: Mapped[str | None] = mapped_column(String)
    url: Mapped[str | None] = mapped_column(String)
    sentiment: Mapped[float | None] = mapped_column(Float)
    published_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    ingested_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default="now()", nullable=False)
