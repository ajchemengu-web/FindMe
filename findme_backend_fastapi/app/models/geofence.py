"""geofences / geofence_events -- ported from 20260702120500_geofences.sql and
20260702120900_geofence_evaluation.sql. Enter/exit detection lives in
app/services/geofence_eval.py, called synchronously right after a location ping is
inserted (app/routers/devices.py) instead of via a Database Webhook + Edge Function."""
import uuid
from datetime import datetime

from geoalchemy2 import Geography
from sqlalchemy import BigInteger, Boolean, CheckConstraint, DateTime, ForeignKey, Index, Integer, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base
from app.models.common import created_at_col


class Geofence(Base):
    __tablename__ = "geofences"
    __table_args__ = (CheckConstraint("radius_m > 0", name="geofences_radius_m_check"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    device_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("devices.id", ondelete="CASCADE"), nullable=False, index=True
    )
    created_by: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    name: Mapped[str] = mapped_column(String, nullable=False)
    center: Mapped[str] = mapped_column(Geography(geometry_type="POINT", srid=4326), nullable=False)
    radius_m: Mapped[int] = mapped_column(Integer, nullable=False)
    active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = created_at_col()


class GeofenceEvent(Base):
    __tablename__ = "geofence_events"
    __table_args__ = (
        CheckConstraint("event_type in ('enter','exit')", name="geofence_events_event_type_check"),
        Index("geofence_events_device_idx", "device_id", "occurred_at"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    geofence_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("geofences.id", ondelete="CASCADE"), nullable=False
    )
    device_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("devices.id", ondelete="CASCADE"), nullable=False
    )
    event_type: Mapped[str] = mapped_column(String, nullable=False)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default="now()", nullable=False)
