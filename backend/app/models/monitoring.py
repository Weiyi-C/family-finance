from sqlalchemy import BigInteger, Date, DateTime, ForeignKey, Integer, Numeric, String, Text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.models.base import Base


class AccountBalanceSnapshot(Base):
    __tablename__ = "account_balance_snapshots"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    account_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("payment_accounts.id"), nullable=False)
    family_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("families.id"), nullable=False)
    snapshot_month: Mapped[str] = mapped_column(Date, nullable=False)
    balance: Mapped[int] = mapped_column(BigInteger, default=0)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())


class ExchangeRate(Base):
    __tablename__ = "exchange_rates"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    base_currency: Mapped[str] = mapped_column(String(10), nullable=False)
    target_currency: Mapped[str] = mapped_column(String(10), nullable=False)
    rate: Mapped[float] = mapped_column(Numeric(15, 6), nullable=False)
    rate_type: Mapped[str] = mapped_column(String(20), default="spot")
    source: Mapped[str | None] = mapped_column(String(50))
    rate_date: Mapped[str] = mapped_column(Date, nullable=False)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())


class AppErrorLog(Base):
    __tablename__ = "app_error_logs"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    level: Mapped[str] = mapped_column(String(20), nullable=False)
    endpoint: Mapped[str | None] = mapped_column(String(200))
    method: Mapped[str | None] = mapped_column(String(10))
    user_id: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("users.id"))
    error_type: Mapped[str | None] = mapped_column(String(100))
    message: Mapped[str | None] = mapped_column(Text)
    traceback: Mapped[str | None] = mapped_column(Text)
    request_data: Mapped[dict | None] = mapped_column(JSONB)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())


class AppSlowQuery(Base):
    __tablename__ = "app_slow_queries"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    endpoint: Mapped[str | None] = mapped_column(String(200))
    query_text: Mapped[str | None] = mapped_column(Text)
    duration_ms: Mapped[int] = mapped_column(Integer, nullable=False)
    user_id: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("users.id"))
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
