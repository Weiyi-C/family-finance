"""AI 建议 API"""

import structlog
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, func, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.database import get_db
from app.models.ai_suggestion import AISuggestion
from app.models.user import Family
from app.models.transaction import Transaction
from app.models.tag import Tag
from app.models.transaction_tag import TransactionTag
from app.models.user import User
from app.schemas.ai_suggestion import (
    AISuggestionResponse,
    AISuggestionListResponse,
    AISuggestionActionRequest,
    AIBatchActionRequest,
)

logger = structlog.get_logger()
router = APIRouter(tags=["AI建议"])


@router.post("/api/ai/analyze")
async def trigger_analysis(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """手动触发AI分析"""
    from app.services.ai_analyzer import AIAnalyzer

    family_result = await db.execute(
        select(Family).where(Family.id == current_user.family_id)
    )
    family = family_result.scalar_one_or_none()
    if not family:
        raise HTTPException(status_code=404, detail="家庭不存在")

    settings = family.settings or {}
    analyzer = AIAnalyzer(family_id=current_user.family_id, family_settings=settings)
    suggestions = await analyzer.run_analysis(db)

    return {
        "message": f"分析完成，生成 {len(suggestions)} 条建议",
        "count": len(suggestions),
    }


@router.get("/api/ai/suggestions", response_model=AISuggestionListResponse)
async def list_suggestions(
    type: str | None = None,
    status: str | None = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """获取AI建议列表"""
    stmt = select(AISuggestion).where(AISuggestion.family_id == current_user.family_id)
    count_stmt = select(func.count()).select_from(AISuggestion).where(
        AISuggestion.family_id == current_user.family_id
    )
    pending_stmt = select(func.count()).select_from(AISuggestion).where(
        AISuggestion.family_id == current_user.family_id,
        AISuggestion.status == "pending",
    )

    if type:
        stmt = stmt.where(AISuggestion.type == type)
        count_stmt = count_stmt.where(AISuggestion.type == type)
    if status:
        stmt = stmt.where(AISuggestion.status == status)
        count_stmt = count_stmt.where(AISuggestion.status == status)

    stmt = stmt.order_by(AISuggestion.created_at.desc()).limit(100)
    result = await db.execute(stmt)
    suggestions = result.scalars().all()

    total = (await db.execute(count_stmt)).scalar() or 0
    pending_count = (await db.execute(pending_stmt)).scalar() or 0

    return AISuggestionListResponse(
        suggestions=[AISuggestionResponse.model_validate(s) for s in suggestions],
        total=total,
        pending_count=pending_count,
    )


@router.post("/api/ai/suggestions/{suggestion_id}/accept")
async def accept_suggestion(
    suggestion_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """接受建议，执行修改"""
    result = await db.execute(
        select(AISuggestion).where(
            AISuggestion.id == suggestion_id,
            AISuggestion.family_id == current_user.family_id,
        )
    )
    suggestion = result.scalar_one_or_none()
    if not suggestion:
        raise HTTPException(status_code=404, detail="建议不存在")
    if suggestion.status != "pending":
        raise HTTPException(status_code=400, detail="建议已处理")

    executed = await _execute_suggestion(suggestion, db)
    suggestion.status = "accepted"
    suggestion.resolved_at = datetime.now(timezone.utc)
    await db.commit()

    return {"message": "建议已接受", "executed": executed}


@router.post("/api/ai/suggestions/{suggestion_id}/reject")
async def reject_suggestion(
    suggestion_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """拒绝建议"""
    result = await db.execute(
        select(AISuggestion).where(
            AISuggestion.id == suggestion_id,
            AISuggestion.family_id == current_user.family_id,
        )
    )
    suggestion = result.scalar_one_or_none()
    if not suggestion:
        raise HTTPException(status_code=404, detail="建议不存在")

    suggestion.status = "rejected"
    suggestion.resolved_at = datetime.now(timezone.utc)
    await db.commit()

    return {"message": "建议已拒绝"}


@router.post("/api/ai/suggestions/batch-action")
async def batch_action(
    body: AIBatchActionRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """批量接受/拒绝建议"""
    result = await db.execute(
        select(AISuggestion).where(
            AISuggestion.id.in_(body.ids),
            AISuggestion.family_id == current_user.family_id,
            AISuggestion.status == "pending",
        )
    )
    suggestions = result.scalars().all()

    executed_count = 0
    for s in suggestions:
        if body.action == "accept":
            await _execute_suggestion(s, db)
            executed_count += 1
        s.status = body.action
        s.resolved_at = datetime.now(timezone.utc)

    await db.commit()
    return {"message": f"已处理 {len(suggestions)} 条建议", "executed": executed_count}


async def _execute_suggestion(suggestion: AISuggestion, db: AsyncSession) -> int:
    """执行建议，返回影响的记录数"""
    s_type = suggestion.type
    s_data = suggestion.suggestion
    txn_ids = suggestion.transaction_ids or []

    if s_type == "tag":
        tags = s_data.get("tags", [])
        if not tags or not txn_ids:
            return 0
        count = 0
        for txn_id in txn_ids:
            for tag_name in tags:
                # 查找或创建标签
                tag_result = await db.execute(
                    select(Tag).where(Tag.family_id == suggestion.family_id, Tag.name == tag_name)
                )
                tag = tag_result.scalar_one_or_none()
                if not tag:
                    tag = Tag(family_id=suggestion.family_id, name=tag_name)
                    db.add(tag)
                    await db.flush()
                # 关联
                existing = await db.execute(
                    select(TransactionTag).where(
                        TransactionTag.transaction_id == txn_id,
                        TransactionTag.tag_id == tag.id,
                    )
                )
                if not existing.first():
                    db.add(TransactionTag(transaction_id=txn_id, tag_id=tag.id))
                    count += 1
        return count

    elif s_type == "category":
        category_name = s_data.get("category_name")
        if not category_name or not txn_ids:
            return 0
        from app.models.category import Category
        cat_result = await db.execute(
            select(Category).where(
                (Category.family_id == suggestion.family_id) | (Category.family_id.is_(None)),
                Category.name == category_name,
            )
        )
        category = cat_result.scalar_one_or_none()
        if not category:
            return 0
        count = 0
        for txn_id in txn_ids:
            # 更新 debit 和 credit 两侧
            result = await db.execute(
                update(Transaction).where(
                    Transaction.id == txn_id,
                    Transaction.family_id == suggestion.family_id,
                ).values(category_id=category.id)
            )
            count += result.rowcount
        return count

    elif s_type == "duplicate":
        # 重复检测：标记但不自动删除，只记录日志
        return 0

    elif s_type == "periodic":
        # 周期识别：暂不自动创建周期交易，需要用户在页面上操作
        return 0

    return 0
