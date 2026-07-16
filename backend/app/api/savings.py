from datetime import datetime, timezone

import structlog
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.database import get_db
from app.models.savings import SavingsGoal
from app.models.user import User
from app.schemas.savings import (
    DepositRequest,
    SavingsGoalCreate,
    SavingsGoalResponse,
    SavingsGoalUpdate,
)

logger = structlog.get_logger()
router = APIRouter(prefix="/api/savings", tags=["储蓄目标"])


def _to_response(goal: SavingsGoal) -> SavingsGoalResponse:
    progress = goal.current_amount / goal.target_amount if goal.target_amount > 0 else 0
    return SavingsGoalResponse(
        id=goal.id,
        family_id=goal.family_id,
        name=goal.name,
        icon=goal.icon,
        color=goal.color,
        target_amount=goal.target_amount,
        current_amount=goal.current_amount,
        account_id=goal.account_id,
        start_date=goal.start_date,
        target_date=goal.target_date,
        status=goal.status,
        achieved_at=goal.achieved_at,
        created_by=goal.created_by,
        progress=round(progress, 4),
    )


@router.get("", response_model=list[SavingsGoalResponse])
async def list_goals(
    status: str | None = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(SavingsGoal).where(SavingsGoal.family_id == current_user.family_id)
    if status:
        stmt = stmt.where(SavingsGoal.status == status)
    stmt = stmt.order_by(SavingsGoal.created_at.desc())
    result = await db.execute(stmt)
    return [_to_response(g) for g in result.scalars()]


@router.post("", response_model=SavingsGoalResponse, status_code=status.HTTP_201_CREATED)
async def create_goal(
    body: SavingsGoalCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    goal = SavingsGoal(
        family_id=current_user.family_id,
        name=body.name,
        icon=body.icon,
        color=body.color,
        target_amount=body.target_amount,
        account_id=body.account_id,
        start_date=body.start_date,
        target_date=body.target_date,
        created_by=current_user.id,
    )
    db.add(goal)
    await db.commit()
    await db.refresh(goal)

    logger.info("savings_goal_created", goal_id=goal.id)
    return _to_response(goal)


@router.get("/{goal_id}", response_model=SavingsGoalResponse)
async def get_goal(
    goal_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(SavingsGoal).where(
            SavingsGoal.id == goal_id,
            SavingsGoal.family_id == current_user.family_id,
        )
    )
    goal = result.scalar_one_or_none()
    if not goal:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="储蓄目标不存在")
    return _to_response(goal)


@router.put("/{goal_id}", response_model=SavingsGoalResponse)
async def update_goal(
    goal_id: int,
    body: SavingsGoalUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(SavingsGoal).where(
            SavingsGoal.id == goal_id,
            SavingsGoal.family_id == current_user.family_id,
        )
    )
    goal = result.scalar_one_or_none()
    if not goal:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="储蓄目标不存在")
    if goal.status != "active":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="只有进行中的目标可编辑")

    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(goal, field, value)
    await db.commit()
    await db.refresh(goal)
    return _to_response(goal)


@router.post("/{goal_id}/deposit", response_model=SavingsGoalResponse)
async def deposit(
    goal_id: int,
    body: DepositRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(SavingsGoal).where(
            SavingsGoal.id == goal_id,
            SavingsGoal.family_id == current_user.family_id,
        )
    )
    goal = result.scalar_one_or_none()
    if not goal:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="储蓄目标不存在")
    if goal.status != "active":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="目标已完成或已放弃")

    goal.current_amount += body.amount
    if goal.current_amount >= goal.target_amount:
        goal.status = "achieved"
        goal.achieved_at = datetime.now(timezone.utc)

    await db.commit()
    await db.refresh(goal)

    logger.info("savings_deposit", goal_id=goal_id, amount=body.amount, status=goal.status)
    return _to_response(goal)


@router.post("/{goal_id}/abandon", response_model=SavingsGoalResponse)
async def abandon_goal(
    goal_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(SavingsGoal).where(
            SavingsGoal.id == goal_id,
            SavingsGoal.family_id == current_user.family_id,
        )
    )
    goal = result.scalar_one_or_none()
    if not goal:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="储蓄目标不存在")
    if goal.status != "active":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="目标已完成或已放弃")

    goal.status = "abandoned"
    await db.commit()
    await db.refresh(goal)

    logger.info("savings_abandoned", goal_id=goal_id)
    return _to_response(goal)


@router.delete("/{goal_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_goal(
    goal_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(SavingsGoal).where(
            SavingsGoal.id == goal_id,
            SavingsGoal.family_id == current_user.family_id,
        )
    )
    goal = result.scalar_one_or_none()
    if not goal:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="储蓄目标不存在")

    await db.delete(goal)
    await db.commit()
