from sqlalchemy import BigInteger, Boolean, DateTime, ForeignKey, Integer, SmallInteger, String
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.models.base import Base


class AutomationRule(Base):
    __tablename__ = "automation_rules"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    family_id: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("families.id"))
    name: Mapped[str] = mapped_column(String(100))
    conditions: Mapped[dict] = mapped_column(JSONB, nullable=False)
    actions: Mapped[dict] = mapped_column(JSONB, nullable=False)
    stage: Mapped[str] = mapped_column(String(20), default="classify")
    priority: Mapped[int] = mapped_column(SmallInteger, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    hit_count: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class AutomationRuleLog(Base):
    __tablename__ = "automation_rule_logs"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    rule_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("automation_rules.id"), nullable=False)
    transaction_id: Mapped[int | None] = mapped_column(BigInteger)
    import_item_id: Mapped[int | None] = mapped_column(BigInteger)
    action_taken: Mapped[str] = mapped_column(String(50))
    before_value: Mapped[dict | None] = mapped_column(JSONB)
    after_value: Mapped[dict | None] = mapped_column(JSONB)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
