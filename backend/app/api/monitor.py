import structlog
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.database import get_db
from app.models.monitoring import AppErrorLog, AppSlowQuery
from app.models.user import User

logger = structlog.get_logger()
router = APIRouter(tags=["系统监控"])


@router.get("/api/monitor/errors")
async def list_errors(
    level: str = Query(None),
    limit: int = Query(50, ge=1, le=200),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """查询错误日志（仅admin/owner）"""
    if current_user.role not in ("owner", "admin"):
        raise HTTPException(status_code=403, detail="权限不足")

    stmt = select(AppErrorLog)
    if level:
        stmt = stmt.where(AppErrorLog.level == level)
    stmt = stmt.order_by(AppErrorLog.created_at.desc()).limit(limit)

    result = await db.execute(stmt)
    return [
        {
            "id": e.id,
            "level": e.level,
            "endpoint": e.endpoint,
            "method": e.method,
            "user_id": e.user_id,
            "error_type": e.error_type,
            "message": e.message,
            "created_at": e.created_at.isoformat() if e.created_at else None,
        }
        for e in result.scalars()
    ]


@router.get("/api/monitor/errors/stats")
async def error_stats(
    days: int = Query(7, ge=1, le=90),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """错误统计（仅admin/owner）"""
    if current_user.role not in ("owner", "admin"):
        raise HTTPException(status_code=403, detail="权限不足")

    from datetime import datetime, timedelta
    since = datetime.now() - timedelta(days=days)

    result = await db.execute(
        select(
            AppErrorLog.level,
            func.count().label("count"),
        )
        .where(AppErrorLog.created_at >= since)
        .group_by(AppErrorLog.level)
    )

    stats = {row.level: row.count for row in result.all()}

    # 按天统计
    daily_result = await db.execute(
        select(
            func.date_trunc("day", AppErrorLog.created_at).label("day"),
            func.count().label("count"),
        )
        .where(AppErrorLog.created_at >= since)
        .group_by(func.date_trunc("day", AppErrorLog.created_at))
        .order_by(func.date_trunc("day", AppErrorLog.created_at))
    )

    daily = [
        {"date": row.day.isoformat() if row.day else None, "count": row.count}
        for row in daily_result.all()
    ]

    return {"by_level": stats, "by_day": daily, "total": sum(stats.values())}


@router.get("/api/monitor/slow-queries")
async def list_slow_queries(
    min_ms: int = Query(1000, ge=100),
    limit: int = Query(50, ge=1, le=200),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """查询慢查询日志（仅admin/owner）"""
    if current_user.role not in ("owner", "admin"):
        raise HTTPException(status_code=403, detail="权限不足")

    result = await db.execute(
        select(AppSlowQuery)
        .where(AppSlowQuery.duration_ms >= min_ms)
        .order_by(AppSlowQuery.duration_ms.desc())
        .limit(limit)
    )

    return [
        {
            "id": q.id,
            "endpoint": q.endpoint,
            "query_text": q.query_text[:200] if q.query_text else None,
            "duration_ms": q.duration_ms,
            "user_id": q.user_id,
            "created_at": q.created_at.isoformat() if q.created_at else None,
        }
        for q in result.scalars()
    ]


@router.get("/api/monitor/summary")
async def monitor_summary(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """监控摘要（仅admin/owner）"""
    if current_user.role not in ("owner", "admin"):
        raise HTTPException(status_code=403, detail="权限不足")

    from datetime import datetime, timedelta
    now = datetime.now()
    today = now.replace(hour=0, minute=0, second=0, microsecond=0)
    week_ago = now - timedelta(days=7)

    # 今日错误数
    today_errors = await db.execute(
        select(func.count()).select_from(AppErrorLog).where(AppErrorLog.created_at >= today)
    )
    today_error_count = today_errors.scalar() or 0

    # 本周慢查询数
    week_slow = await db.execute(
        select(func.count()).select_from(AppSlowQuery).where(AppSlowQuery.created_at >= week_ago)
    )
    week_slow_count = week_slow.scalar() or 0

    # 最近错误
    recent_errors = await db.execute(
        select(AppErrorLog).order_by(AppErrorLog.created_at.desc()).limit(5)
    )
    recent = [
        {
            "level": e.level,
            "endpoint": e.endpoint,
            "message": e.message[:100] if e.message else None,
            "created_at": e.created_at.isoformat() if e.created_at else None,
        }
        for e in recent_errors.scalars()
    ]

    return {
        "today_errors": today_error_count,
        "week_slow_queries": week_slow_count,
        "recent_errors": recent,
    }
