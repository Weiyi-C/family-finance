"""分析洞察 API"""

import structlog
from fastapi import APIRouter, Depends, Query
from sqlalchemy import or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.database import get_db
from app.models.insight import Insight
from app.models.user import User

logger = structlog.get_logger()
router = APIRouter(tags=["分析洞察"])


@router.get("/api/insights")
async def list_insights(
    type: str | None = None,
    is_read: bool | None = None,
    limit: int = Query(50, ge=1, le=200),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """获取洞察列表"""
    stmt = select(Insight).where(Insight.family_id == current_user.family_id)
    if type:
        stmt = stmt.where(Insight.type == type)
    if is_read is not None:
        stmt = stmt.where(Insight.is_read == is_read)
    stmt = stmt.order_by(Insight.created_at.desc()).limit(limit)
    result = await db.execute(stmt)
    return [dict(r) for r in result.mappings().all()]


@router.get("/api/insights/unread-count")
async def unread_count(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """未读洞察数量"""
    from sqlalchemy import func
    result = await db.execute(
        select(func.count()).select_from(Insight).where(
            Insight.family_id == current_user.family_id,
            Insight.is_read == False,
        )
    )
    return {"count": result.scalar() or 0}


@router.put("/api/insights/{insight_id}/read")
async def mark_read(
    insight_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """标记洞察已读"""
    result = await db.execute(
        update(Insight).where(
            Insight.id == insight_id,
            Insight.family_id == current_user.family_id,
        ).values(is_read=True)
    )
    await db.commit()
    return {"success": result.rowcount > 0}


@router.put("/api/insights/read-all")
async def mark_all_read(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """标记所有洞察已读"""
    await db.execute(
        update(Insight).where(
            Insight.family_id == current_user.family_id,
            Insight.is_read == False,
        ).values(is_read=True)
    )
    await db.commit()
    return {"success": True}


@router.post("/api/insights/analyze")
async def trigger_analyze(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """手动触发分析洞察"""
    from app.services.analyze_service import run_analyze
    insights = await run_analyze(db, current_user.family_id)

    from app.models.notification import Notification
    for ins in insights:
        insight = Insight(
            family_id=current_user.family_id,
            type=ins["type"],
            title=ins["title"],
            content=ins["content"],
            data=ins.get("data"),
        )
        db.add(insight)
        notif = Notification(
            family_id=current_user.family_id,
            user_id=current_user.id,
            type="insight",
            title=ins["title"],
            content=ins["content"],
            related_type="insight",
        )
        db.add(notif)

    await db.commit()
    return {"message": f"分析完成，生成 {len(insights)} 条洞察", "count": len(insights)}
