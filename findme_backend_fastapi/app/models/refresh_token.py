"""
refresh_tokens -- did not exist in the Supabase version (supabase-js/GoTrue managed
sessions and refresh internally). Now that this service issues its own JWTs, refresh
tokens need a server-side record so they can be looked up, rotated, and revoked
(logout, "log out everywhere", detected reuse) rather than trusted as bearer-only
forever-valid secrets.

Only a hash of the token is stored (same reasoning as password hashing) -- if this
table leaked, the tokens in it still couldn't be replayed directly.
"""
import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base
from app.models.common import created_at_col, uuid_pk


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id: Mapped[uuid.UUID] = uuid_pk()
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    token_hash: Mapped[str] = mapped_column(String, nullable=False, unique=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    # Set when this token is exchanged for a new one (rotation) -- lets logout-everywhere
    # and reuse-detection walk the chain if ever needed; not currently read anywhere.
    replaced_by_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True))
    created_at: Mapped[datetime] = created_at_col()
