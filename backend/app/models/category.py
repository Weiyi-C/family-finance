from sqlalchemy import BigInteger, Boolean, ForeignKey, Integer, SmallInteger, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from sqlalchemy import DateTime

from app.models.base import Base


class Category(Base):
    __tablename__ = "categories"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    family_id: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("families.id"))
    parent_id: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("categories.id"))
    level: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    name: Mapped[str] = mapped_column(String(50), nullable=False)
    icon: Mapped[str | None] = mapped_column(String(50))
    color: Mapped[str | None] = mapped_column(String(20))
    type: Mapped[str] = mapped_column(String(10), default="expense")
    sort_order: Mapped[int] = mapped_column(SmallInteger, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    parent: Mapped["Category | None"] = relationship(
        back_populates="children", remote_side="Category.id", foreign_keys=[parent_id]
    )
    children: Mapped[list["Category"]] = relationship(
        back_populates="parent", foreign_keys=[parent_id]
    )
