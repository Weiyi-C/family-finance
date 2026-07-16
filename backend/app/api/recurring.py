from datetime import date, timedelta
from calendar import monthrange

import structlog
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.deps import get_current_user
from app.database import get_db
from app.models.recurring import RecurringTransaction, RecurringTransactionLog
from app.models.user import User
from app.schemas.recurring import (
    RecurringCreate,
    RecurringLogResponse,
    RecurringResponse,
    RecurringUpdate,
)

logger = structlog.get_logger()
router = APIRouter(prefix="/api/recurring", tags=["周期性交易"])


def _calc_next_generate(frequency: str, from_date: date, day_of_month: int | None,
                        day_of_week: int | None, interval_value: int) -> date:
    if frequency == "daily":
        return from_date + timedelta(days=interval_value)
    if frequency == "weekly":
        return from_date + timedelta(weeks=interval_value)
    if frequency == "monthly":
        m = from_date.month + interval_value
        y = from_date.year + (m - 1) // 12
        m = (m - 1) % 12 + 1
        d = min(day_of_month or from_date.day, monthrange(y, m)[1])
        return date(y, m, d)
    if frequency == "yearly":
        return date(from_date.year + interval_value, day_of_month or from_date.month, from_date.day)
    return from_date + timedelta(days=1)


@router.get("", response_model=list[RecurringResponse])
async def list_recurring(
    is_active: bool | None = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(RecurringTransaction).where(
        RecurringTransaction.family_id == current_user.family_id
    )
    if is_active is not None:
        stmt = stmt.where(RecurringTransaction.is_active == is_active)
    stmt = stmt.order_by(RecurringTransaction.next_generate)
    result = await db.execute(stmt)
    return [RecurringResponse.model_validate(r) for r in result.scalars()]


@router.post("", response_model=RecurringResponse, status_code=status.HTTP_201_CREATED)
async def create_recurring(
    body: RecurringCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if body.frequency == "monthly" and body.day_of_month is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="月度周期必须指定 day_of_month")
    if body.frequency == "weekly" and body.day_of_week is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="周度周期必须指定 day_of_week")

    next_gen = body.start_date

    recurring = RecurringTransaction(
        family_id=current_user.family_id,
        book_id=body.book_id,
        type=body.type,
        amount=body.amount,
        currency=body.currency,
        category_id=body.category_id,
        sub_category_id=body.sub_category_id,
        payment_account_id=body.payment_account_id,
        payment_channel_id=body.payment_channel_id,
        platform_id=body.platform_id,
        merchant_name=body.merchant_name,
        description=body.description,
        frequency=body.frequency,
        day_of_month=body.day_of_month,
        day_of_week=body.day_of_week,
        month_of_year=body.month_of_year,
        interval_value=body.interval_value,
        start_date=body.start_date,
        end_date=body.end_date,
        remind_days_before=body.remind_days_before,
        remind_time=body.remind_time,
        next_generate=next_gen,
        created_by=current_user.id,
    )
    db.add(recurring)
    await db.commit()
    await db.refresh(recurring)

    logger.info("recurring_created", recurring_id=recurring.id, frequency=body.frequency)
    return RecurringResponse.model_validate(recurring)


@router.get("/{recurring_id}", response_model=RecurringResponse)
async def get_recurring(
    recurring_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(RecurringTransaction).where(
            RecurringTransaction.id == recurring_id,
            RecurringTransaction.family_id == current_user.family_id,
        )
    )
    recurring = result.scalar_one_or_none()
    if not recurring:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="周期性交易不存在")
    return RecurringResponse.model_validate(recurring)


@router.put("/{recurring_id}", response_model=RecurringResponse)
async def update_recurring(
    recurring_id: int,
    body: RecurringUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(RecurringTransaction).where(
            RecurringTransaction.id == recurring_id,
            RecurringTransaction.family_id == current_user.family_id,
        )
    )
    recurring = result.scalar_one_or_none()
    if not recurring:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="周期性交易不存在")

    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(recurring, field, value)

    await db.commit()
    await db.refresh(recurring)
    return RecurringResponse.model_validate(recurring)


@router.delete("/{recurring_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_recurring(
    recurring_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(RecurringTransaction).where(
            RecurringTransaction.id == recurring_id,
            RecurringTransaction.family_id == current_user.family_id,
        )
    )
    recurring = result.scalar_one_or_none()
    if not recurring:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="周期性交易不存在")

    await db.delete(recurring)
    await db.commit()

    logger.info("recurring_deleted", recurring_id=recurring_id)


@router.post("/{recurring_id}/generate", response_model=RecurringLogResponse)
async def generate_transaction(
    recurring_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(RecurringTransaction).where(
            RecurringTransaction.id == recurring_id,
            RecurringTransaction.family_id == current_user.family_id,
        )
    )
    recurring = result.scalar_one_or_none()
    if not recurring:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="周期性交易不存在")
    if not recurring.is_active:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="周期性交易已停止")
    if recurring.end_date and recurring.next_generate and recurring.next_generate > recurring.end_date:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="已超出结束日期")

    scheduled = recurring.next_generate or recurring.start_date
    today = date.today()

    log = RecurringTransactionLog(
        recurring_id=recurring.id,
        scheduled_date=scheduled,
        actual_date=today,
        status="generated",
        amount=recurring.amount,
    )
    db.add(log)

    recurring.last_generated = today
    recurring.total_generated += 1
    recurring.next_generate = _calc_next_generate(
        recurring.frequency, scheduled,
        recurring.day_of_month, recurring.day_of_week,
        recurring.interval_value,
    )

    if recurring.end_date and recurring.next_generate > recurring.end_date:
        recurring.is_active = False

    await db.commit()
    await db.refresh(log)

    logger.info("recurring_generated", recurring_id=recurring.id, scheduled=scheduled)
    return RecurringLogResponse.model_validate(log)


@router.get("/{recurring_id}/logs", response_model=list[RecurringLogResponse])
async def list_recurring_logs(
    recurring_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(RecurringTransaction).where(
            RecurringTransaction.id == recurring_id,
            RecurringTransaction.family_id == current_user.family_id,
        )
    )
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="周期性交易不存在")

    logs = await db.execute(
        select(RecurringTransactionLog)
        .where(RecurringTransactionLog.recurring_id == recurring_id)
        .order_by(RecurringTransactionLog.scheduled_date.desc())
    )
    return [RecurringLogResponse.model_validate(l) for l in logs.scalars()]
