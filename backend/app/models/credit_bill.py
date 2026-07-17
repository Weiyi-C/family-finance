from sqlalchemy import BigInteger, DateTime, ForeignKey, Integer, SmallInteger, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.models.base import Base


class CreditCardBill(Base):
    __tablename__ = "credit_card_bills"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    account_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("payment_accounts.id"), nullable=False)
    family_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("families.id"), nullable=False)
    bill_year: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    bill_month: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    billing_date: Mapped[str] = mapped_column(DateTime(timezone=False), nullable=False)
    due_date: Mapped[str] = mapped_column(DateTime(timezone=False), nullable=False)
    total_amount: Mapped[int] = mapped_column(BigInteger, default=0)
    paid_amount: Mapped[int] = mapped_column(BigInteger, default=0)
    min_payment: Mapped[int] = mapped_column(BigInteger, default=0)
    status: Mapped[str] = mapped_column(String(20), default="pending")
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    __table_args__ = (UniqueConstraint("account_id", "bill_year", "bill_month"),)
