from sqlalchemy import BigInteger, Boolean, ForeignKey, Integer, SmallInteger, String
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func
from sqlalchemy import DateTime

from app.models.base import Base


class PaymentAccount(Base):
    __tablename__ = "payment_accounts"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    family_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("families.id"), nullable=False)
    user_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("users.id"), nullable=False)
    template_id: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("account_type_templates.id"))
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    type_code: Mapped[str] = mapped_column(String(30), nullable=False)
    icon: Mapped[str | None] = mapped_column(String(50))
    color: Mapped[str | None] = mapped_column(String(20))
    bank_name: Mapped[str | None] = mapped_column(String(50))
    bank_code: Mapped[str | None] = mapped_column(String(20))
    card_tail: Mapped[str | None] = mapped_column(String(10))
    card_type: Mapped[str | None] = mapped_column(String(20))
    initial_balance: Mapped[int] = mapped_column(BigInteger, default=0)
    credit_limit: Mapped[int | None] = mapped_column(BigInteger)
    used_amount: Mapped[int] = mapped_column(BigInteger, default=0)
    billing_day: Mapped[int | None] = mapped_column(SmallInteger)
    due_day: Mapped[int | None] = mapped_column(SmallInteger)
    grace_days: Mapped[int | None] = mapped_column(SmallInteger)
    is_shared: Mapped[bool] = mapped_column(Boolean, default=False)
    shared_with: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("users.id"))
    share_type: Mapped[str | None] = mapped_column(String(30))
    group_name: Mapped[str | None] = mapped_column(String(30))
    sort_order: Mapped[int] = mapped_column(SmallInteger, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    is_hidden: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
