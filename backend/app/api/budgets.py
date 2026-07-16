import calendar
from datetime import date, datetime, timedelta, timezone

import structlog
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.database import get_db
from app.models.budget import Budget
from app.models.transaction import Transaction
from app.models.user import User
from app.schemas.budget import BudgetCreate, BudgetResponse, BudgetUpdate, BudgetUsage

logger = structlog.get_logger()
router = APIRouter(prefix="/api/budgets", tags=["预算"])


def _period_range(budget: Budget) -> tuple[date, date]:
    if budget.period == "monthly":
        start = date(budget.year, budget.month or 1, 1)
        _, last_day = calendar.monthrange(budget.year, budget.month or 1)
        end = date(budget.year, budget.month or 1, last_day)
    elif budget.period == "weekly":
        start = budget.week_start_date
        end = start + timedelta(days=6)
    else:
        start = date(budget.year, 1, 1)
        end = date(budget.year, 12, 31)
    return start, end


async def _calc_spent(db: AsyncSession, budget: Budget, start: date, end: date) -> int:
    conditions = [
        Transaction.family_id == budget.family_id,
        Transaction.entry_side == "debit",
        Transaction.is_deleted == False,
        Transaction.type == "expense",
        Transaction.transaction_time >= datetime(start.year, start.month, start.day, tzinfo=timezone.utc),
        Transaction.transaction_time <= datetime(end.year, end.month, end.day, 23, 59, 59, tzinfo=timezone.utc),
    ]
    if budget.category_id:
        conditions.append(Transaction.category_id == budget.category_id)
    if budget.book_id:
        conditions.append(Transaction.book_id == budget.book_id)

    result = await db.execute(
        select(func.coalesce(func.sum(Transaction.amount), 0)).where(and_(*conditions))
    )
    return result.scalar()


@router.get("", response_model=list[BudgetResponse])
async def list_budgets(
    year: int | None = None,
    month: int | None = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(Budget).where(Budget.family_id == current_user.family_id)
    if year:
        stmt = stmt.where(Budget.year == year)
    if month:
        stmt = stmt.where(Budget.month == month)
    stmt = stmt.order_by(Budget.year.desc(), Budget.month.desc(), Budget.id)
    result = await db.execute(stmt)
    return [BudgetResponse.model_validate(b) for b in result.scalars()]


@router.post("", response_model=BudgetResponse, status_code=status.HTTP_201_CREATED)
async def create_budget(
    body: BudgetCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if body.period == "monthly" and body.month is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="月度预算必须指定月份")
    if body.period == "weekly" and body.week_start_date is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="周预算必须指定开始日期")

    budget = Budget(
        family_id=current_user.family_id,
        book_id=body.book_id,
        category_id=body.category_id,
        amount=body.amount,
        currency=body.currency,
        period=body.period,
        year=body.year,
        month=body.month,
        week_start_date=body.week_start_date,
        rollover=body.rollover,
        alert_threshold=body.alert_threshold,
    )
    db.add(budget)
    await db.commit()
    await db.refresh(budget)

    logger.info("budget_created", budget_id=budget.id, user_id=current_user.id)
    return BudgetResponse.model_validate(budget)


@router.get("/{budget_id}", response_model=BudgetResponse)
async def get_budget(
    budget_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Budget).where(Budget.id == budget_id, Budget.family_id == current_user.family_id)
    )
    budget = result.scalar_one_or_none()
    if not budget:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="预算不存在")
    return BudgetResponse.model_validate(budget)


@router.put("/{budget_id}", response_model=BudgetResponse)
async def update_budget(
    budget_id: int,
    body: BudgetUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Budget).where(Budget.id == budget_id, Budget.family_id == current_user.family_id)
    )
    budget = result.scalar_one_or_none()
    if not budget:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="预算不存在")

    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(budget, field, value)

    await db.commit()
    await db.refresh(budget)
    return BudgetResponse.model_validate(budget)


@router.delete("/{budget_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_budget(
    budget_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Budget).where(Budget.id == budget_id, Budget.family_id == current_user.family_id)
    )
    budget = result.scalar_one_or_none()
    if not budget:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="预算不存在")

    await db.delete(budget)
    await db.commit()

    logger.info("budget_deleted", budget_id=budget_id, user_id=current_user.id)


@router.get("/{budget_id}/usage", response_model=BudgetUsage)
async def get_budget_usage(
    budget_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Budget).where(Budget.id == budget_id, Budget.family_id == current_user.family_id)
    )
    budget = result.scalar_one_or_none()
    if not budget:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="预算不存在")

    start, end = _period_range(budget)
    spent = await _calc_spent(db, budget, start, end)
    total = budget.amount + budget.rollover_amount
    remaining = total - spent
    usage_rate = spent / total if total > 0 else 0

    return BudgetUsage(
        budget_id=budget.id,
        amount=total,
        spent=spent,
        remaining=remaining,
        usage_rate=round(usage_rate, 4),
        is_over=spent > total,
        period_start=start,
        period_end=end,
    )
