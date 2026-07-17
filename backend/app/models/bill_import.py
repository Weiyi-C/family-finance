from sqlalchemy import BigInteger, DateTime, ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.models.base import Base


class BillImport(Base):
    __tablename__ = "bill_imports"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    family_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("families.id"), nullable=False)
    book_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("account_books.id"), nullable=False)
    source: Mapped[str] = mapped_column(String(30), nullable=False)
    file_url: Mapped[str | None] = mapped_column(String(500))
    file_format: Mapped[str | None] = mapped_column(String(10))
    status: Mapped[str] = mapped_column(String(20), default="pending")
    total_rows: Mapped[int] = mapped_column(Integer, default=0)
    parsed_count: Mapped[int] = mapped_column(Integer, default=0)
    matched_count: Mapped[int] = mapped_column(Integer, default=0)
    new_count: Mapped[int] = mapped_column(Integer, default=0)
    parse_log: Mapped[dict | None] = mapped_column(JSONB)
    imported_by: Mapped[int] = mapped_column(BigInteger, ForeignKey("users.id"), nullable=False)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class BillImportItem(Base):
    __tablename__ = "bill_import_items"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    import_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("bill_imports.id"), nullable=False)
    raw_data: Mapped[dict] = mapped_column(JSONB, nullable=False)
    parsed_amount: Mapped[int | None] = mapped_column(BigInteger)
    parsed_time: Mapped[str | None] = mapped_column(DateTime(timezone=True))
    parsed_merchant: Mapped[str | None] = mapped_column(String(200))
    parsed_category: Mapped[str | None] = mapped_column(String(50))
    matched_txn_id: Mapped[int | None] = mapped_column(BigInteger)
    action: Mapped[str] = mapped_column(String(20), default="pending")
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
