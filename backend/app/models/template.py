from sqlalchemy import BigInteger, Boolean, SmallInteger, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class AccountTypeTemplate(Base):
    __tablename__ = "account_type_templates"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    type_code: Mapped[str] = mapped_column(String(30), unique=True, nullable=False)
    name: Mapped[str] = mapped_column(String(50), nullable=False)
    icon: Mapped[str | None] = mapped_column(String(50))
    group_name: Mapped[str] = mapped_column(String(30), nullable=False)
    is_credit: Mapped[bool] = mapped_column(Boolean, default=False)
    has_balance: Mapped[bool] = mapped_column(Boolean, default=True)
    has_credit_limit: Mapped[bool] = mapped_column(Boolean, default=False)
    has_billing_day: Mapped[bool] = mapped_column(Boolean, default=False)
    has_due_day: Mapped[bool] = mapped_column(Boolean, default=False)
    default_icon: Mapped[str | None] = mapped_column(String(50))
    default_color: Mapped[str | None] = mapped_column(String(20))
    sort_order: Mapped[int] = mapped_column(SmallInteger, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
