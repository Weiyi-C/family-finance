from sqlalchemy import BigInteger, Boolean, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.models.base import Base


class MerchantAlias(Base):
    __tablename__ = "merchant_aliases"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    family_id: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("families.id"))
    original_name: Mapped[str] = mapped_column(String(200), nullable=False)
    alias_name: Mapped[str] = mapped_column(String(100), nullable=False)
    category_id: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("categories.id"))
    sub_category_id: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("categories.id"))
    platform_id: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("platforms.id"))
    hit_count: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
