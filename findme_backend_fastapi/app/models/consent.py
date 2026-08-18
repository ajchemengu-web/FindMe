"""
consents / consent_audit_log -- ported from 20260702120200_consents.sql. The
state-machine legality checks that used to live in the enforce_consent_transition()
trigger, and the plan-limit checks from enforce_consent_plan_limits(), now live in
app/services/authz.py's transition_consent()/create_consent_request(), called from
app/routers/consents.py -- there is no trigger silently guarding writes anymore, so
every write path MUST go through those service functions, never a raw session.add().
"""
import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, String
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base
from app.models.common import created_at_col, updated_at_col, uuid_pk


class Consent(Base):
    __tablename__ = "consents"
    __table_args__ = (
        CheckConstraint("status in ('pending','active','denied','revoked')", name="consents_status_check"),
        CheckConstraint("scope in ('precise','city')", name="consents_scope_check"),
        CheckConstraint("grantor_id <> grantee_id", name="consents_not_self"),
        # Mirrors `consents_one_live_pair`: at most one pending/active row per
        # (grantor, grantee) at a time. Postgres partial unique indexes need a raw
        # index rather than a declarative UniqueConstraint (which can't carry a WHERE
        # clause) -- created in the Alembic migration, not here; see
        # alembic/versions/0001_initial.py.
    )

    id: Mapped[uuid.UUID] = uuid_pk()
    grantor_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    grantee_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    status: Mapped[str] = mapped_column(String, nullable=False, default="pending")
    scope: Mapped[str] = mapped_column(String, nullable=False, default="precise")
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    requested_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default="now()", nullable=False)
    responded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    revoked_by: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"))
    created_at: Mapped[datetime] = created_at_col()
    updated_at: Mapped[datetime] = updated_at_col()


class ConsentAuditLog(Base):
    __tablename__ = "consent_audit_log"
    __table_args__ = (
        CheckConstraint(
            "action in ('requested','approved','denied','revoked')", name="consent_audit_log_action_check"
        ),
    )

    id: Mapped[uuid.UUID] = uuid_pk()
    consent_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("consents.id", ondelete="CASCADE"), nullable=False, index=True
    )
    actor_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    action: Mapped[str] = mapped_column(String, nullable=False)
    audit_metadata: Mapped[dict[str, Any]] = mapped_column("metadata", JSONB, nullable=False, default=dict)
    created_at: Mapped[datetime] = created_at_col()
