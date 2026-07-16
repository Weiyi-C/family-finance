from sqlalchemy import BigInteger, Boolean, DateTime, ForeignKey, Numeric, SmallInteger, String
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.models.base import Base


class Budget(Base):
    __tablename__ = "budgets"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    family_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("families.id"), nullable=False)
    book_id: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("account_books.id"))
    category_id: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("categories.id"))
    amount: Mapped[int] = mapped_column(BigInteger, nullable=False)
    currency: Mapped[str] = mapped_column(String(3), default="CNY")
    period: Mapped[str] = mapped_column(String(20), nullable=False)
    year: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    month: Mapped[int | None] = mapped_column(SmallInteger)
    week_start_date: Mapped[str | None] = mapped_column(DateTime)
    rollover: Mapped[bool] = mapped_column(Boolean, default=False)
    rollover_amount: Mapped[int] = mapped_column(BigInteger, default=0)
    alert_threshold: Mapped[float] = mapped_column(Numeric(5, 2), default=0.8)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
