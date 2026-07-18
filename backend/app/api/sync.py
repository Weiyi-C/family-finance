import time

import structlog
from fastapi import APIRouter, Depends
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.database import get_db
from app.models.sync import SyncChangeLog, ClientSyncState, SyncLog
from app.models.user import User, FamilySyncSeq
from app.schemas.extra import SyncPullRequest, SyncPushRequest, SyncResponse

logger = structlog.get_logger()
router = APIRouter(tags=["离线同步"])


@router.post("/api/sync/pull", response_model=SyncResponse)
async def sync_pull(
    body: SyncPullRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(SyncChangeLog)
        .where(
            SyncChangeLog.family_id == current_user.family_id,
            SyncChangeLog.seq > body.last_seq,
        )
        .order_by(SyncChangeLog.seq)
        .limit(body.limit + 1)
    )
    rows = list(result.scalars().all())
    has_more = len(rows) > body.limit
    rows = rows[:body.limit]

    changes = []
    for r in rows:
        changes.append({
            "seq": r.seq,
            "table_name": r.table_name,
            "record_id": r.record_id,
            "operation": r.operation,
            "version": r.version,
            "change_data": r.change_data,
            "changed_at": r.changed_at.isoformat() if r.changed_at else None,
        })

    seq_result = await db.execute(
        select(FamilySyncSeq.current_seq).where(FamilySyncSeq.family_id == current_user.family_id)
    )
    current_seq = seq_result.scalar() or 0

    return SyncResponse(changes=changes, current_seq=current_seq, has_more=has_more)


@router.post("/api/sync/push")
async def sync_push(
    body: SyncPushRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    start = time.monotonic()
    seq_result = await db.execute(
        select(FamilySyncSeq).where(FamilySyncSeq.family_id == current_user.family_id)
    )
    seq_row = seq_result.scalar_one_or_none()
    if not seq_row:
        seq_row = FamilySyncSeq(family_id=current_user.family_id, current_seq=0)
        db.add(seq_row)
        await db.flush()

    applied = 0
    for change in body.changes:
        seq_row.current_seq += 1
        log = SyncChangeLog(
            family_id=current_user.family_id,
            seq=seq_row.current_seq,
            table_name=change["table_name"],
            record_id=change["record_id"],
            operation=change["operation"],
            version=change.get("version", 1),
            changed_by=current_user.id,
            change_data=change.get("change_data"),
            family_id_check=current_user.family_id,
        )
        db.add(log)
        applied += 1

    state_result = await db.execute(
        select(ClientSyncState).where(
            ClientSyncState.client_id == body.client_id,
            ClientSyncState.family_id == current_user.family_id,
        )
    )
    state = state_result.scalar_one_or_none()
    if not state:
        state = ClientSyncState(
            client_id=body.client_id,
            family_id=current_user.family_id,
            user_id=current_user.id,
        )
        db.add(state)
    state.last_pushed_seq = seq_row.current_seq
    from datetime import datetime, timezone
    state.last_active_at = datetime.now(timezone.utc)

    duration_ms = int((time.monotonic() - start) * 1000)
    sync_log = SyncLog(
        client_id=body.client_id,
        family_id=current_user.family_id,
        sync_type="push",
        record_count=applied,
        duration_ms=duration_ms,
        status="success",
    )
    db.add(sync_log)

    await db.commit()
    return {"applied": applied, "current_seq": seq_row.current_seq}


@router.get("/api/sync/status")
async def get_sync_status(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """获取同步状态"""
    # 获取当前序列号
    seq_result = await db.execute(
        select(FamilySyncSeq.current_seq).where(FamilySyncSeq.family_id == current_user.family_id)
    )
    current_seq = seq_result.scalar() or 0

    # 获取所有客户端状态
    states_result = await db.execute(
        select(ClientSyncState).where(ClientSyncState.family_id == current_user.family_id)
    )
    clients = []
    for state in states_result.scalars():
        last_seq = max(state.last_pushed_seq or 0, state.last_pulled_seq or 0)
        clients.append({
            "client_id": state.client_id,
            "device_type": state.device_type,
            "device_name": state.device_name,
            "last_pushed_seq": state.last_pushed_seq,
            "last_pulled_seq": state.last_pulled_seq,
            "last_active_at": state.last_active_at.isoformat() if state.last_active_at else None,
            "lag": current_seq - last_seq,
        })

    # 最近同步日志
    logs_result = await db.execute(
        select(SyncLog)
        .where(SyncLog.family_id == current_user.family_id)
        .order_by(SyncLog.created_at.desc())
        .limit(10)
    )
    recent_logs = []
    for log in logs_result.scalars():
        recent_logs.append({
            "id": log.id,
            "client_id": log.client_id,
            "sync_type": log.sync_type,
            "record_count": log.record_count,
            "status": log.status,
            "duration_ms": log.duration_ms,
            "created_at": log.created_at.isoformat() if log.created_at else None,
        })

    return {
        "current_seq": current_seq,
        "clients": clients,
        "recent_logs": recent_logs,
    }
