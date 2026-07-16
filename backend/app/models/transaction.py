import uuid

from sqlalchemy import BigInteger, Boolean, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func
from sqlalchemy import Numeric

from app.models.base import Base


class Transaction(Base):
    __tablename__ = "transactions"
    __table_args__ = {"postgresql_partition_by": "RANGE (transaction_time)"}

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    family_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("families.id"), nullable=False)
    book_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("account_books.id"), nullable=False)
    entry_id: Mapped[int | None] = mapped_column(BigInteger)
    entry_side: Mapped[str] = mapped_column(String(4), nullable=False)
    type: Mapped[str] = mapped_column(String(20), nullable=False)
    amount: Mapped[int] = mapped_column(BigInteger, nullable=False)
    currency: Mapped[str] = mapped_column(String(3), default="CNY")
    original_amount: Mapped[int | None] = mapped_column(BigInteger)
    original_currency: Mapped[str | None] = mapped_column(String(3))
    exchange_rate: Mapped[float | None] = mapped_column(Numeric(10, 6))
    category_id: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("categories.id"))
    sub_category_id: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("categories.id"))
    detail_category_id: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("categories.id"))
    payment_account_id: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("payment_accounts.id"))
    payment_channel_id: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("payment_channels.id"))
    platform_id: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("platforms.id"))
    merchant_name: Mapped[str | None] = mapped_column(String(200))
    description: Mapped[str | None] = mapped_column(String(500))
    transaction_time: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False)
    recorded_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
    recorded_by: Mapped[int] = mapped_column(BigInteger, ForeignKey("users.id"), nullable=False)
    paid_by: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("users.id"))
    is_quick_entry: Mapped[bool] = mapped_column(Boolean, default=False)
    completion_status: Mapped[str] = mapped_column(String(20), default="complete")
    recurring_id: Mapped[int | None] = mapped_column(BigInteger)
    import_id: Mapped[int | None] = mapped_column(BigInteger)
    raw_data: Mapped[dict | None] = mapped_column(JSONB)
    version: Mapped[int] = mapped_column(Integer, default=1)
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
