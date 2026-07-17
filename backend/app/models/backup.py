from sqlalchemy import BigInteger, Boolean, DateTime, Integer, String
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.models.base import Base


class BackupConfig(Base):
    __tablename__ = "backup_configs"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    family_id: Mapped[int] = mapped_column(BigInteger, nullable=False)
    backup_type: Mapped[str] = mapped_column(String(30), nullable=False)
    schedule: Mapped[str] = mapped_column(String(50), nullable=False)
    is_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    target: Mapped[str] = mapped_column(String(30), nullable=False)
    target_config: Mapped[dict | None] = mapped_column(JSONB)
    retention_days: Mapped[int] = mapped_column(Integer, default=30)
    max_backups: Mapped[int] = mapped_column(Integer, default=10)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class BackupLog(Base):
    __tablename__ = "backup_logs"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    backup_type: Mapped[str] = mapped_column(String(30), nullable=False)
    backup_target: Mapped[str] = mapped_column(String(30), nullable=False)
    file_path: Mapped[str | None] = mapped_column(String(500))
    file_size: Mapped[int | None] = mapped_column(BigInteger)
    file_format: Mapped[str | None] = mapped_column(String(20))
    table_counts: Mapped[dict | None] = mapped_column(JSONB)
    status: Mapped[str] = mapped_column(String(20), default="success")
    error_message: Mapped[str | None] = mapped_column(String(500))
    duration_ms: Mapped[int | None] = mapped_column(Integer)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
