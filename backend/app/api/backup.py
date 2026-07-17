import json
import os
import time

import structlog
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import FileResponse
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.core.deps import get_current_user
from app.database import get_db, async_session
from app.models.backup import BackupConfig, BackupLog
from app.models.user import User
from app.schemas.extra import BackupConfigCreate, BackupConfigResponse, BackupLogResponse

logger = structlog.get_logger()
router = APIRouter(tags=["备份"])


@router.get("/api/backup/configs", response_model=list[BackupConfigResponse])
async def list_configs(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(BackupConfig).where(BackupConfig.family_id == current_user.family_id)
    )
    return [BackupConfigResponse.model_validate(c) for c in result.scalars()]


@router.post("/api/backup/configs", response_model=BackupConfigResponse, status_code=201)
async def create_config(
    body: BackupConfigCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    config = BackupConfig(family_id=current_user.family_id, **body.model_dump())
    db.add(config)
    await db.commit()
    await db.refresh(config)
    return BackupConfigResponse.model_validate(config)


@router.post("/api/backup/trigger", response_model=BackupLogResponse)
async def trigger_backup(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    backup_dir = settings.BACKUP_DIR
    os.makedirs(backup_dir, exist_ok=True)

    start = time.monotonic()
    timestamp = time.strftime("%Y%m%d_%H%M%S")
    filename = f"backup_{current_user.family_id}_{timestamp}.json"
    filepath = os.path.join(backup_dir, filename)

    table_counts = {}
    family_scoped_tables = [
        "categories", "payment_accounts", "transactions", "tags",
        "budgets", "debts", "debt_repayments",
        "recurring_transactions", "savings_goals", "reimbursements",
        "automation_rules", "merchant_aliases",
    ]
    all_tables = family_scoped_tables + ["transaction_tags", "recurring_transaction_logs", "reimbursement_items"]

    try:
        backup_data = {}
        for table in all_tables:
            try:
                async with async_session() as session:
                    if table in family_scoped_tables:
                        result = await session.execute(text(f"SELECT * FROM {table} WHERE family_id = :fid"), {"fid": current_user.family_id})
                    else:
                        result = await session.execute(text(f"SELECT * FROM {table}"))
                    rows = [dict(row._mapping) for row in result.fetchall()]
                    for row in rows:
                        for k, v in row.items():
                            if hasattr(v, "isoformat"):
                                row[k] = v.isoformat()
                    backup_data[table] = rows
                    table_counts[table] = len(rows)
            except Exception as e:
                logger.warning("backup_table_skip", table=table, error=str(e))
                table_counts[table] = "skipped"
                backup_data[table] = []

        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(backup_data, f, ensure_ascii=False, indent=2, default=str)

        duration_ms = int((time.monotonic() - start) * 1000)
        file_size = os.path.getsize(filepath)

        log = BackupLog(
            backup_type="manual",
            backup_target="local",
            file_path=filepath,
            file_size=file_size,
            file_format="json",
            table_counts=table_counts,
            status="success",
            duration_ms=duration_ms,
        )
        db.add(log)
        await db.commit()
        await db.refresh(log)
        logger.info("backup_created", family_id=current_user.family_id, file=filename, size=file_size)
        return BackupLogResponse.model_validate(log)

    except Exception as e:
        log = BackupLog(
            backup_type="manual",
            backup_target="local",
            status="failed",
            error_message=str(e),
        )
        db.add(log)
        await db.commit()
        await db.refresh(log)
        raise HTTPException(status_code=500, detail=f"备份失败: {e}")


@router.get("/api/backup/logs", response_model=list[BackupLogResponse])
async def list_logs(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(BackupLog).order_by(BackupLog.created_at.desc()).limit(50)
    )
    return [BackupLogResponse.model_validate(l) for l in result.scalars()]


@router.get("/api/backup/download/{log_id}")
async def download_backup(
    log_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(BackupLog).where(BackupLog.id == log_id))
    log = result.scalar_one_or_none()
    if not log or not log.file_path:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="备份文件不存在")
    if not os.path.exists(log.file_path):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="备份文件已丢失")
    return FileResponse(log.file_path, filename=os.path.basename(log.file_path), media_type="application/json")


@router.delete("/api/backup/logs/{log_id}", status_code=204)
async def delete_backup_log(
    log_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(BackupLog).where(BackupLog.id == log_id))
    log = result.scalar_one_or_none()
    if not log:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="备份记录不存在")
    if log.file_path and os.path.exists(log.file_path):
        os.remove(log.file_path)
    await db.delete(log)
    await db.commit()
