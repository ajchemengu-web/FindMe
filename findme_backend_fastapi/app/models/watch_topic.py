"""watch_topics -- ported from 20260702120700_alerts_watchlist.sql."""
import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, ForeignKey, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base
from app.models.common import created_at_col


class WatchTopic(Base):
    __tablename__ = "watch_topics"
    __table_args__ = (
        CheckConstraint("topic_type in ('region','company','keyword')", name="watch_topics_topic_type_check"),
        UniqueConstraint("owner_id", "topic_type", "value", name="watch_topics_owner_topic_value_key"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    owner_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    topic_type: Mapped[str] = mapped_column(String, nullable=False)
    value: Mapped[str] = mapped_column(String, nullable=False)
    created_at: Mapped[datetime] = created_at_col()
