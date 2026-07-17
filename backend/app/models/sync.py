from sqlalchemy import BigInteger, DateTime, ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.models.base import Base


class SyncChangeLog(Base):
    __tablename__ = "sync_change_log"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    family_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("families.id"), nullable=False)
    seq: Mapped[int] = mapped_column(BigInteger, nullable=False)
    table_name: Mapped[str] = mapped_column(String(50), nullable=False)
    record_id: Mapped[int] = mapped_column(BigInteger, nullable=False)
    operation: Mapped[str] = mapped_column(String(10), nullable=False)
    version: Mapped[int] = mapped_column(Integer, nullable=False)
    changed_by: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("users.id"))
    changed_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
    change_data: Mapped[dict | None] = mapped_column(JSONB)
    family_id_check: Mapped[int] = mapped_column(BigInteger, nullable=False)


class ClientSyncState(Base):
    __tablename__ = "client_sync_state"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    client_id: Mapped[str] = mapped_column(String(100), nullable=False)
    family_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("families.id"), nullable=False)
    last_sync_seq: Mapped[int] = mapped_column(BigInteger, default=0)
    last_sync_at: Mapped[str | None] = mapped_column(DateTime(timezone=True))
    device_info: Mapped[str | None] = mapped_column(String(200))
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class SyncLog(Base):
    __tablename__ = "sync_logs"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    client_id: Mapped[str] = mapped_column(String(100), nullable=False)
    family_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("families.id"), nullable=False)
    direction: Mapped[str] = mapped_column(String(10), nullable=False)
    change_count: Mapped[int] = mapped_column(Integer, default=0)
    last_seq: Mapped[int] = mapped_column(BigInteger)
    duration_ms: Mapped[int | None] = mapped_column(Integer)
    status: Mapped[str] = mapped_column(String(20), default="success")
    error_message: Mapped[str | None] = mapped_column(String(500))
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
