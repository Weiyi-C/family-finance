import structlog
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.database import get_db
from app.models.credit_bill import CreditCardBill
from app.models.user import User
from app.schemas.extra import CreditBillResponse, CreditBillPayRequest

logger = structlog.get_logger()
router = APIRouter(tags=["信用卡账单"])


@router.get("/api/credit-bills", response_model=list[CreditBillResponse])
async def list_bills(
    account_id: int | None = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(CreditCardBill).where(CreditCardBill.family_id == current_user.family_id)
    if account_id:
        stmt = stmt.where(CreditCardBill.account_id == account_id)
    stmt = stmt.order_by(CreditCardBill.bill_year.desc(), CreditCardBill.bill_month.desc())
    result = await db.execute(stmt)
    return [CreditBillResponse.model_validate(b) for b in result.scalars()]


@router.get("/api/credit-bills/summary")
async def bill_summary(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(
            func.sum(CreditCardBill.total_amount - CreditCardBill.paid_amount).label("total_due"),
            func.count().label("bill_count"),
        ).where(
            CreditCardBill.family_id == current_user.family_id,
            CreditCardBill.status.in_(["pending", "partial", "overdue"]),
        )
    )
    row = result.one()
    return {"total_due": row.total_due or 0, "bill_count": row.bill_count}


@router.get("/api/credit-bills/{bill_id}", response_model=CreditBillResponse)
async def get_bill(
    bill_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(CreditCardBill).where(
            CreditCardBill.id == bill_id,
            CreditCardBill.family_id == current_user.family_id,
        )
    )
    bill = result.scalar_one_or_none()
    if not bill:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="账单不存在")
    return CreditBillResponse.model_validate(bill)


@router.post("/api/credit-bills/{bill_id}/pay", response_model=CreditBillResponse)
async def pay_bill(
    bill_id: int,
    body: CreditBillPayRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(CreditCardBill).where(
            CreditCardBill.id == bill_id,
            CreditCardBill.family_id == current_user.family_id,
        )
    )
    bill = result.scalar_one_or_none()
    if not bill:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="账单不存在")
    bill.paid_amount += body.amount
    if bill.paid_amount >= bill.total_amount:
        bill.status = "paid"
    elif bill.paid_amount > 0:
        bill.status = "partial"
    await db.commit()
    await db.refresh(bill)
    return CreditBillResponse.model_validate(bill)
