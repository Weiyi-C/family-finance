import calendar
import structlog
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, func, and_, extract
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.database import get_db
from app.models.account import PaymentAccount
from app.models.credit_bill import CreditCardBill
from app.models.transaction import Transaction
from app.models.user import User
from app.schemas.extra import CreditBillResponse, CreditBillPayRequest

logger = structlog.get_logger()
router = APIRouter(tags=["信用卡账单"])


@router.post("/api/credit-bills/generate")
async def generate_bills(
    year: int | None = None,
    month: int | None = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """生成信用卡账单（基于交易记录自动汇总）"""
    try:
        now = datetime.now()
        target_year = year or now.year
        target_month = month or now.month

        # 查找所有信用账户（银行信用卡 + 花呗 + 京东白条等）
        CREDIT_TYPES = ["bank_credit", "alipay_huabei", "jd_baitiao"]
        accounts_result = await db.execute(
            select(PaymentAccount).where(
                PaymentAccount.family_id == current_user.family_id,
                PaymentAccount.type_code.in_(CREDIT_TYPES),
                PaymentAccount.is_active == True,
            )
        )
        credit_accounts = accounts_result.scalars().all()

        if not credit_accounts:
            return {"message": "没有信用卡账户", "generated": 0}

        generated = 0
        for account in credit_accounts:
            # 检查是否已存在该月账单
            existing = await db.execute(
                select(CreditCardBill).where(
                    CreditCardBill.account_id == account.id,
                    CreditCardBill.bill_year == target_year,
                    CreditCardBill.bill_month == target_month,
                )
            )
            if existing.scalar_one_or_none():
                continue

            # 计算账单周期
            due_day = account.due_day or 20

            if account.billing_cycle_type == 'natural_month':
                # 自然月：账单周期为当月1号到月末最后一天
                bill_start = datetime(target_year, target_month, 1)
                last_day = calendar.monthrange(target_year, target_month)[1]
                bill_end = datetime(target_year, target_month, last_day)

                # 还款日：下月的due_day
                if target_month == 12:
                    due_date = datetime(target_year + 1, 1, due_day)
                else:
                    due_date = datetime(target_year, target_month + 1, due_day)
            else:
                billing_day = account.billing_day or 1

                # 账单开始日期：上月账单日+1
                if target_month == 1:
                    bill_start = datetime(target_year - 1, 12, billing_day + 1)
                else:
                    bill_start = datetime(target_year, target_month - 1, billing_day + 1)

                # 账单结束日期：本月账单日
                bill_end = datetime(target_year, target_month, billing_day)

                # 还款日：如果还款日 < 账单日，则还款日在下月
                if due_day <= billing_day:
                    if target_month == 12:
                        due_date = datetime(target_year + 1, 1, due_day)
                    else:
                        due_date = datetime(target_year, target_month + 1, due_day)
                else:
                    due_date = datetime(target_year, target_month, due_day)

            # 查询该周期内的支出总额
            total_result = await db.execute(
                select(func.coalesce(func.sum(Transaction.amount), 0)).where(
                    Transaction.payment_account_id == account.id,
                    Transaction.family_id == current_user.family_id,
                    Transaction.entry_side == "debit",
                    Transaction.type == "expense",
                    Transaction.is_deleted == False,
                    Transaction.transaction_time >= bill_start,
                    Transaction.transaction_time <= bill_end,
                )
            )
            total_amount = total_result.scalar() or 0

            if total_amount > 0:
                bill = CreditCardBill(
                    account_id=account.id,
                    family_id=current_user.family_id,
                    bill_year=target_year,
                    bill_month=target_month,
                    billing_date=bill_end.date(),
                    due_date=due_date.date(),
                    total_amount=int(total_amount),
                    min_payment=int(total_amount) // 10,  # 最低还款额10%
                    status="pending",
                )
                db.add(bill)
                generated += 1

        await db.commit()
        return {"message": f"生成 {generated} 个账单", "generated": generated}
    except Exception as e:
        logger.error("generate_bills_error", error=str(e))
        raise HTTPException(status_code=500, detail=f"生成账单失败: {str(e)}")


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
