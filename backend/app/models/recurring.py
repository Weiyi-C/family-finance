from sqlalchemy import BigInteger, Boolean, Date, DateTime, ForeignKey, Integer, SmallInteger, String, Time
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.models.base import Base


class RecurringTransaction(Base):
    __tablename__ = "recurring_transactions"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    family_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("families.id"), nullable=False)
    book_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("account_books.id"), nullable=False)
    type: Mapped[str] = mapped_column(String(20), nullable=False)
    amount: Mapped[int] = mapped_column(BigInteger, nullable=False)
    currency: Mapped[str] = mapped_column(String(3), default="CNY")
    category_id: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("categories.id"))
    sub_category_id: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("categories.id"))
    payment_account_id: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("payment_accounts.id"))
    payment_channel_id: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("payment_channels.id"))
    platform_id: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("platforms.id"))
    merchant_name: Mapped[str | None] = mapped_column(String(200))
    description: Mapped[str | None] = mapped_column(String(500))
    frequency: Mapped[str] = mapped_column(String(20), nullable=False)
    day_of_month: Mapped[int | None] = mapped_column(SmallInteger)
    day_of_week: Mapped[int | None] = mapped_column(SmallInteger)
    month_of_year: Mapped[int | None] = mapped_column(SmallInteger)
    interval_value: Mapped[int] = mapped_column(SmallInteger, default=1)
    start_date: Mapped[str] = mapped_column(Date, nullable=False)
    end_date: Mapped[str | None] = mapped_column(Date)
    remind_days_before: Mapped[int] = mapped_column(SmallInteger, default=1)
    remind_time: Mapped[str | None] = mapped_column(Time)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    last_generated: Mapped[str | None] = mapped_column(Date)
    next_generate: Mapped[str | None] = mapped_column(Date)
    total_generated: Mapped[int] = mapped_column(Integer, default=0)
    created_by: Mapped[int] = mapped_column(BigInteger, ForeignKey("users.id"), nullable=False)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    logs: Mapped[list["RecurringTransactionLog"]] = relationship(back_populates="recurring", cascade="all, delete-orphan")


class RecurringTransactionLog(Base):
    __tablename__ = "recurring_transaction_logs"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    recurring_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("recurring_transactions.id"), nullable=False)
    transaction_id: Mapped[int | None] = mapped_column(BigInteger)
    scheduled_date: Mapped[str] = mapped_column(Date, nullable=False)
    actual_date: Mapped[str | None] = mapped_column(Date)
    status: Mapped[str] = mapped_column(String(20), default="pending")
    amount: Mapped[int | None] = mapped_column(BigInteger)
    note: Mapped[str | None] = mapped_column(String(200))
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())

    recurring: Mapped[RecurringTransaction] = relationship(back_populates="logs")
