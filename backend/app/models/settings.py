from sqlalchemy import BigInteger, Boolean, DateTime, ForeignKey, Integer, SmallInteger, String, Time
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.models.base import Base


class UserSettings(Base):
    __tablename__ = "user_settings"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("users.id"), unique=True, nullable=False)
    default_currency: Mapped[str] = mapped_column(String(3), default="CNY")
    month_start_day: Mapped[int] = mapped_column(SmallInteger, default=1)
    theme: Mapped[str] = mapped_column(String(20), default="light")
    language: Mapped[str] = mapped_column(String(10), default="zh-CN")
    date_format: Mapped[str] = mapped_column(String(20), default="YYYY-MM-DD")
    number_format: Mapped[str] = mapped_column(String(20), default="1,234.56")
    default_book_id: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("account_books.id"))
    quick_entry_mode: Mapped[str] = mapped_column(String(20), default="minimal")
    confirm_before_save: Mapped[bool] = mapped_column(Boolean, default=True)
    notify_budget_alert: Mapped[bool] = mapped_column(Boolean, default=True)
    notify_recurring: Mapped[bool] = mapped_column(Boolean, default=True)
    notify_sync: Mapped[bool] = mapped_column(Boolean, default=False)
    quiet_hours_start: Mapped[str | None] = mapped_column(Time)
    quiet_hours_end: Mapped[str | None] = mapped_column(Time)
    auto_sync: Mapped[bool] = mapped_column(Boolean, default=True)
    sync_on_wifi_only: Mapped[bool] = mapped_column(Boolean, default=False)
    settings_json: Mapped[dict | None] = mapped_column(JSONB)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
