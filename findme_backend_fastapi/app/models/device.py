"""devices -- ported 1:1 from 20260702120300_devices.sql. Visibility/write rules that
used to be RLS policies now live in app/services/authz.py."""
import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, SmallInteger, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base
from app.models.common import created_at_col, updated_at_col, uuid_pk


class Device(Base):
    __tablename__ = "devices"
    __table_args__ = (
        CheckConstraint(
            "device_type in ('phone','tablet','laptop','router','tracker','other')",
            name="devices_device_type_check",
        ),
        CheckConstraint("platform in ('ios','android','web','other')", name="devices_platform_check"),
        CheckConstraint("battery_pct between 0 and 100", name="devices_battery_pct_check"),
    )

    id: Mapped[uuid.UUID] = uuid_pk()
    owner_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    nickname: Mapped[str] = mapped_column(String, nullable=False)
    device_type: Mapped[str] = mapped_column(String, nullable=False, default="phone")
    platform: Mapped[str | None] = mapped_column(String)
    is_self_owned: Mapped[bool] = mapped_column(default=True, nullable=False)
    push_token: Mapped[str | None] = mapped_column(String)
    battery_pct: Mapped[int | None] = mapped_column(SmallInteger)
    last_seen_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = created_at_col()
    updated_at: Mapped[datetime] = updated_at_col()
