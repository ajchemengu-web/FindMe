"""
pending_invites -- new table, no Supabase-era equivalent (the original app never
supported inviting someone who doesn't have a FindMe account yet; consent requests
could only target an existing user). A row here means "inviter wants to watch this
phone number's location once it signs up" -- app/services/auth.py's signup() checks
for matching unconsumed rows and creates the real Consent row(s) at that point.
"""
import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base
from app.models.common import created_at_col, uuid_pk


class PendingInvite(Base):
    __tablename__ = "pending_invites"
    __table_args__ = (CheckConstraint("scope in ('precise','city')", name="pending_invites_scope_check"),)

    id: Mapped[uuid.UUID] = uuid_pk()
    inviter_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    # Normalized phone number (see app/services/phone.py's normalize_phone) -- only
    # phone invites are supported for now, no email-sending capability exists.
    contact_phone: Mapped[str] = mapped_column(String, nullable=False, index=True)
    scope: Mapped[str] = mapped_column(String, nullable=False, default="precise")
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    consumed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = created_at_col()
