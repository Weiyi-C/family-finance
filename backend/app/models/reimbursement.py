from sqlalchemy import BigInteger, DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.models.base import Base


class Reimbursement(Base):
    __tablename__ = "reimbursements"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    family_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("families.id"), nullable=False)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    total_amount: Mapped[int] = mapped_column(BigInteger, nullable=False)
    status: Mapped[str] = mapped_column(String(20), default="draft")
    submitted_at: Mapped[str | None] = mapped_column(DateTime(timezone=True))
    approved_at: Mapped[str | None] = mapped_column(DateTime(timezone=True))
    received_at: Mapped[str | None] = mapped_column(DateTime(timezone=True))
    received_amount: Mapped[int | None] = mapped_column(BigInteger)
    submitted_by: Mapped[int] = mapped_column(BigInteger, ForeignKey("users.id"), nullable=False)
    description: Mapped[str | None] = mapped_column(String(500))
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    items: Mapped[list["ReimbursementItem"]] = relationship(back_populates="reimbursement", cascade="all, delete-orphan")


class ReimbursementItem(Base):
    __tablename__ = "reimbursement_items"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    reimbursement_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("reimbursements.id"), nullable=False)
    transaction_id: Mapped[int] = mapped_column(BigInteger, nullable=False)
    amount: Mapped[int] = mapped_column(BigInteger, nullable=False)
    description: Mapped[str | None] = mapped_column(String(200))

    reimbursement: Mapped[Reimbursement] = relationship(back_populates="items")
