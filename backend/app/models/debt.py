from sqlalchemy import BigInteger, Date, DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.models.base import Base


class Debt(Base):
    __tablename__ = "debts"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    family_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("families.id"), nullable=False)
    type: Mapped[str] = mapped_column(String(20), nullable=False)
    counterparty: Mapped[str] = mapped_column(String(100), nullable=False)
    amount: Mapped[int] = mapped_column(BigInteger, nullable=False)
    currency: Mapped[str] = mapped_column(String(3), default="CNY")
    payment_account_id: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("payment_accounts.id"))
    debt_date: Mapped[str] = mapped_column(Date, nullable=False)
    due_date: Mapped[str | None] = mapped_column(Date)
    status: Mapped[str] = mapped_column(String(20), default="pending")
    repaid_amount: Mapped[int] = mapped_column(BigInteger, default=0)
    description: Mapped[str | None] = mapped_column(String(500))
    created_by: Mapped[int] = mapped_column(BigInteger, ForeignKey("users.id"), nullable=False)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    repayments: Mapped[list["DebtRepayment"]] = relationship(back_populates="debt", cascade="all, delete-orphan")


class DebtRepayment(Base):
    __tablename__ = "debt_repayments"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    debt_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("debts.id"), nullable=False)
    amount: Mapped[int] = mapped_column(BigInteger, nullable=False)
    repayment_date: Mapped[str] = mapped_column(Date, nullable=False)
    payment_account_id: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("payment_accounts.id"))
    description: Mapped[str | None] = mapped_column(String(200))
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())

    debt: Mapped[Debt] = relationship(back_populates="repayments")
