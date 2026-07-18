import structlog
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.deps import get_current_user
from app.database import get_db
from app.models.debt import Debt, DebtRepayment
from app.models.user import User
from app.schemas.debt import (
    DebtCreate,
    DebtResponse,
    DebtUpdate,
    RepaymentCreate,
    RepaymentResponse,
)

logger = structlog.get_logger()
router = APIRouter(prefix="/api/debts", tags=["借贷"])


def _update_status(debt: Debt):
    if debt.repaid_amount >= debt.amount:
        debt.status = "settled"
    elif debt.repaid_amount > 0:
        debt.status = "partial"
    else:
        debt.status = "pending"


@router.get("", response_model=list[DebtResponse])
async def list_debts(
    type: str | None = None,
    status: str | None = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = (
        select(Debt)
        .options(selectinload(Debt.repayments))
        .where(Debt.family_id == current_user.family_id)
    )
    if type:
        stmt = stmt.where(Debt.type == type)
    if status:
        stmt = stmt.where(Debt.status == status)
    stmt = stmt.order_by(Debt.debt_date.desc())
    result = await db.execute(stmt)
    return [DebtResponse.model_validate(d) for d in result.scalars()]


@router.get("/summary")
async def get_debt_summary(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """借贷汇总"""
    # 借出汇总
    lend_result = await db.execute(
        select(
            func.count().label("count"),
            func.sum(Debt.amount).label("total"),
            func.sum(Debt.repaid_amount).label("repaid"),
        ).where(
            Debt.family_id == current_user.family_id,
            Debt.type == "lend",
            Debt.status != "settled",
        )
    )
    lend = lend_result.one()

    # 借入汇总
    borrow_result = await db.execute(
        select(
            func.count().label("count"),
            func.sum(Debt.amount).label("total"),
            func.sum(Debt.repaid_amount).label("repaid"),
        ).where(
            Debt.family_id == current_user.family_id,
            Debt.type == "borrow",
            Debt.status != "settled",
        )
    )
    borrow = borrow_result.one()

    return {
        "lend": {
            "count": lend.count or 0,
            "total": lend.total or 0,
            "repaid": lend.repaid or 0,
            "remaining": (lend.total or 0) - (lend.repaid or 0),
        },
        "borrow": {
            "count": borrow.count or 0,
            "total": borrow.total or 0,
            "repaid": borrow.repaid or 0,
            "remaining": (borrow.total or 0) - (borrow.repaid or 0),
        },
    }


@router.post("", response_model=DebtResponse, status_code=status.HTTP_201_CREATED)
async def create_debt(
    body: DebtCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    debt = Debt(
        family_id=current_user.family_id,
        type=body.type,
        counterparty=body.counterparty,
        amount=body.amount,
        currency=body.currency,
        payment_account_id=body.payment_account_id,
        debt_date=body.debt_date,
        due_date=body.due_date,
        description=body.description,
        created_by=current_user.id,
    )
    db.add(debt)
    await db.commit()
    await db.refresh(debt, ["repayments"])

    logger.info("debt_created", debt_id=debt.id, type=body.type, amount=body.amount)
    return DebtResponse.model_validate(debt)


@router.get("/{debt_id}", response_model=DebtResponse)
async def get_debt(
    debt_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Debt)
        .options(selectinload(Debt.repayments))
        .where(Debt.id == debt_id, Debt.family_id == current_user.family_id)
    )
    debt = result.scalar_one_or_none()
    if not debt:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="借贷不存在")
    return DebtResponse.model_validate(debt)


@router.put("/{debt_id}", response_model=DebtResponse)
async def update_debt(
    debt_id: int,
    body: DebtUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Debt)
        .options(selectinload(Debt.repayments))
        .where(Debt.id == debt_id, Debt.family_id == current_user.family_id)
    )
    debt = result.scalar_one_or_none()
    if not debt:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="借贷不存在")

    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(debt, field, value)

    await db.commit()
    await db.refresh(debt, ["repayments"])
    return DebtResponse.model_validate(debt)


@router.post("/{debt_id}/repayments", response_model=RepaymentResponse, status_code=status.HTTP_201_CREATED)
async def add_repayment(
    debt_id: int,
    body: RepaymentCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Debt).where(Debt.id == debt_id, Debt.family_id == current_user.family_id)
    )
    debt = result.scalar_one_or_none()
    if not debt:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="借贷不存在")
    if debt.status == "settled":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="借贷已结清")

    repayment = DebtRepayment(
        debt_id=debt_id,
        amount=body.amount,
        repayment_date=body.repayment_date,
        payment_account_id=body.payment_account_id,
        description=body.description,
    )
    db.add(repayment)
    debt.repaid_amount += body.amount
    _update_status(debt)
    await db.commit()
    await db.refresh(repayment)

    logger.info("repayment_added", debt_id=debt_id, amount=body.amount, status=debt.status)
    return RepaymentResponse.model_validate(repayment)


@router.delete("/{debt_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_debt(
    debt_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Debt).where(Debt.id == debt_id, Debt.family_id == current_user.family_id)
    )
    debt = result.scalar_one_or_none()
    if not debt:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="借贷不存在")

    await db.delete(debt)
    await db.commit()

    logger.info("debt_deleted", debt_id=debt_id, user_id=current_user.id)
