"""mpesa_transactions -- ported from 20260702121600_mpesa_billing.sql. Only
app/services/mpesa.py (STK push) and app/routers/billing.py's callback handler write
this table -- the client only ever reads its own row's status (mirrors the old
"select_own, no insert/update policy" split)."""
import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base
from app.models.common import created_at_col


class MpesaTransaction(Base):
    __tablename__ = "mpesa_transactions"
    __table_args__ = (
        CheckConstraint("tier in ('plus','pro')", name="mpesa_transactions_tier_check"),
        CheckConstraint("amount_kes > 0", name="mpesa_transactions_amount_kes_check"),
        CheckConstraint("status in ('pending','success','failed')", name="mpesa_transactions_status_check"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    tier: Mapped[str] = mapped_column(String, nullable=False)
    amount_kes: Mapped[int] = mapped_column(Integer, nullable=False)
    phone: Mapped[str] = mapped_column(String, nullable=False)
    checkout_request_id: Mapped[str] = mapped_column(String, nullable=False, unique=True)
    merchant_request_id: Mapped[str | None] = mapped_column(String)
    status: Mapped[str] = mapped_column(String, nullable=False, default="pending")
    mpesa_receipt_number: Mapped[str | None] = mapped_column(String)
    result_desc: Mapped[str | None] = mapped_column(String)
    created_at: Mapped[datetime] = created_at_col()
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
