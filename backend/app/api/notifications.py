import structlog
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, update, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.database import get_db
from app.models.notification import Notification
from app.models.user import User

logger = structlog.get_logger()
router = APIRouter(tags=["通知"])


@router.get("/api/notifications")
async def list_notifications(
    is_read: bool | None = None,
    limit: int = 50,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(Notification).where(Notification.user_id == current_user.id)
    if is_read is not None:
        stmt = stmt.where(Notification.is_read == is_read)
    stmt = stmt.order_by(Notification.created_at.desc()).limit(limit)
    result = await db.execute(stmt)
    rows = result.scalars().all()
    return [
        {
            "id": n.id, "user_id": n.user_id, "family_id": n.family_id,
            "type": n.type, "title": n.title, "content": n.content,
            "related_id": n.related_id, "related_type": n.related_type,
            "is_read": n.is_read, "read_at": n.read_at.isoformat() if n.read_at else None,
            "channel": n.channel, "send_status": n.send_status,
            "created_at": n.created_at.isoformat() if n.created_at else None,
        }
        for n in rows
    ]


@router.get("/api/notifications/unread")
async def unread_count(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(func.count()).select_from(Notification).where(
            Notification.user_id == current_user.id,
            Notification.is_read == False,
        )
    )
    return {"count": result.scalar() or 0}


@router.put("/api/notifications/{notif_id}/read")
async def mark_read(
    notif_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Notification).where(
            Notification.id == notif_id,
            Notification.user_id == current_user.id,
        )
    )
    notif = result.scalar_one_or_none()
    if not notif:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="通知不存在")
    from datetime import datetime, timezone
    notif.is_read = True
    notif.read_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(notif)
    return {"id": notif.id, "is_read": True, "read_at": notif.read_at.isoformat()}


@router.put("/api/notifications/read-all")
async def mark_all_read(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from datetime import datetime, timezone
    await db.execute(
        update(Notification)
        .where(Notification.user_id == current_user.id, Notification.is_read == False)
        .values(is_read=True, read_at=datetime.now(timezone.utc))
    )
    await db.commit()
    return {"message": "全部已读"}
