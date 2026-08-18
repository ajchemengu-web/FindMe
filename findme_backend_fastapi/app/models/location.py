"""
location_pings -- ported from 20260702120400_location_pings.sql. The most sensitive
table in the schema; who can read it is decided entirely by
app/services/authz.py:visible_device_ids_for()/check_can_read_precise() -- there is no
database-level RLS fallback here, so every router touching this table must call through
that service layer.
"""
import uuid
from datetime import datetime

from geoalchemy2 import Geography
from sqlalchemy import BigInteger, CheckConstraint, DateTime, Float, ForeignKey, Index, SmallInteger
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base
from app.models.common import created_at_col


class LocationPing(Base):
    __tablename__ = "location_pings"
    __table_args__ = (
        CheckConstraint("battery_pct between 0 and 100", name="location_pings_battery_pct_check"),
        Index("location_pings_device_time_idx", "device_id", "recorded_at"),
        Index("location_pings_geo_idx", "location", postgresql_using="gist"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    device_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("devices.id", ondelete="CASCADE"), nullable=False, index=True
    )
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default="now()", nullable=False)
    location: Mapped[str] = mapped_column(Geography(geometry_type="POINT", srid=4326), nullable=False)
    accuracy_m: Mapped[float | None] = mapped_column(Float)
    battery_pct: Mapped[int | None] = mapped_column(SmallInteger)
    created_at: Mapped[datetime] = created_at_col()
