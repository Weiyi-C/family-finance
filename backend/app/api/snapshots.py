import structlog
from datetime import date, datetime
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, func, and_, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.database import get_db
from app.models.monitoring import AccountBalanceSnapshot, ExchangeRate, AppErrorLog, AppSlowQuery
from app.models.transaction import Transaction
from app.models.account import PaymentAccount
from app.models.user import User

logger = structlog.get_logger()
router = APIRouter(tags=["余额快照"])


@router.post("/api/snapshots/trigger")
async def trigger_snapshots(
    month: str = Query(None, description="快照月份，格式YYYY-MM-DD，默认当月1日"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """生成账户余额快照"""
    if not month:
        today = date.today()
        month = f"{today.year}-{today.month:02d}-01"

    snapshot_date = date.fromisoformat(month)

    # 获取所有活跃账户
    accounts_result = await db.execute(
        select(PaymentAccount).where(
            PaymentAccount.family_id == current_user.family_id,
            PaymentAccount.is_active == True,
        )
    )
    accounts = accounts_result.scalars().all()

    created = 0
    for account in accounts:
        # 检查是否已有该月快照
        existing = await db.execute(
            select(AccountBalanceSnapshot).where(
                AccountBalanceSnapshot.account_id == account.id,
                AccountBalanceSnapshot.snapshot_month == snapshot_date,
            )
        )
        if existing.scalar_one_or_none():
            continue

        # 计算余额
        income_result = await db.execute(
            select(func.coalesce(func.sum(Transaction.amount), 0)).where(
                Transaction.payment_account_id == account.id,
                Transaction.family_id == current_user.family_id,
                Transaction.type == "income",
                Transaction.is_deleted == False,
                Transaction.entry_side == "debit",
                Transaction.transaction_time < datetime.combine(snapshot_date, datetime.min.time()),
            )
        )
        income = income_result.scalar() or 0

        expense_result = await db.execute(
            select(func.coalesce(func.sum(Transaction.amount), 0)).where(
                Transaction.payment_account_id == account.id,
                Transaction.family_id == current_user.family_id,
                Transaction.type == "expense",
                Transaction.is_deleted == False,
                Transaction.entry_side == "debit",
                Transaction.transaction_time < datetime.combine(snapshot_date, datetime.min.time()),
            )
        )
        expense = expense_result.scalar() or 0

        balance = account.initial_balance + income - expense

        snapshot = AccountBalanceSnapshot(
            account_id=account.id,
            family_id=current_user.family_id,
            snapshot_month=snapshot_date,
            balance=balance,
        )
        db.add(snapshot)
        created += 1

    await db.commit()
    return {"created": created, "month": month}


@router.get("/api/snapshots")
async def list_snapshots(
    account_id: int = Query(None),
    start_month: str = Query(None, description="开始月份 YYYY-MM-DD"),
    end_month: str = Query(None, description="结束月份 YYYY-MM-DD"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """查询余额快照"""
    stmt = select(AccountBalanceSnapshot).where(
        AccountBalanceSnapshot.family_id == current_user.family_id
    )
    if account_id:
        stmt = stmt.where(AccountBalanceSnapshot.account_id == account_id)
    if start_month:
        stmt = stmt.where(AccountBalanceSnapshot.snapshot_month >= start_month)
    if end_month:
        stmt = stmt.where(AccountBalanceSnapshot.snapshot_month <= end_month)

    stmt = stmt.order_by(AccountBalanceSnapshot.snapshot_month.desc())
    result = await db.execute(stmt)

    return [
        {
            "id": s.id,
            "account_id": s.account_id,
            "snapshot_month": s.snapshot_month.isoformat(),
            "balance": s.balance,
        }
        for s in result.scalars()
    ]
