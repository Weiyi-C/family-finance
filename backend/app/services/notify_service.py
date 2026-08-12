"""提醒通知服务 — notify 阶段"""

import calendar
from datetime import date, datetime, timedelta, timezone

import structlog
from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.budget import Budget
from app.models.credit_bill import CreditCardBill
from app.models.notification import Notification
from app.models.transaction import Transaction
from app.models.user import Family

logger = structlog.get_logger()

# 大额交易阈值（分），默认 5000 元
DEFAULT_LARGE_EXPENSE_THRESHOLD = 500000
# 连续无交易天数阈值
DEFAULT_NO_TRANSACTION_DAYS = 7


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


async def _send_notification(db: AsyncSession, family_id: int, user_id: int,
                             title: str, content: str, notif_type: str,
                             related_id: int | None = None, related_type: str | None = None):
    """发送通知（避免重复：同类型同关联ID当天不重复发送）"""
    today_start = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
    
    # 检查是否已发送过
    existing = await db.execute(
        select(Notification).where(
            Notification.family_id == family_id,
            Notification.type == notif_type,
            Notification.related_id == related_id,
            Notification.created_at >= today_start,
        ).limit(1)
    )
    if existing.scalar_one_or_none():
        return  # 今天已发送过，跳过

    notif = Notification(
        family_id=family_id,
        user_id=user_id,
        type=notif_type,
        title=title,
        content=content,
        related_id=related_id,
        related_type=related_type,
    )
    db.add(notif)


async def check_budget_alerts(db: AsyncSession, family_id: int, user_id: int):
    """检查预算超支"""
    now = datetime.now()
    budgets = await db.execute(
        select(Budget).where(
            Budget.family_id == family_id,
            Budget.period == "monthly",
            Budget.year == now.year,
            Budget.month == now.month,
        )
    )
    alerts = 0
    for budget in budgets.scalars():
        start, end = _period_range(budget)
        result = await db.execute(
            select(func.coalesce(func.sum(Transaction.amount), 0)).where(
                Transaction.family_id == family_id,
                Transaction.entry_side == "debit",
                Transaction.is_deleted == False,
                Transaction.type == "expense",
                Transaction.transaction_time >= datetime(start.year, start.month, start.day, tzinfo=timezone.utc),
                Transaction.transaction_time <= datetime(end.year, end.month, end.day, 23, 59, 59, tzinfo=timezone.utc),
                Transaction.category_id == budget.category_id if budget.category_id else True,
            )
        )
        spent = result.scalar() or 0
        total = budget.amount + budget.rollover_amount
        if total > 0 and spent >= total * budget.alert_threshold:
            percent = int(spent / total * 100)
            from app.models.category import Category
            cat_name = "总预算"
            if budget.category_id:
                cat_result = await db.execute(select(Category.name).where(Category.id == budget.category_id))
                cat_name = cat_result.scalar() or "未知分类"
            
            await _send_notification(
                db, family_id, user_id,
                "预算预警",
                f"{cat_name}本月支出已达预算的{percent}%（¥{spent/100:.0f}/¥{total/100:.0f}）",
                "budget_alert",
                related_id=budget.id,
                related_type="budget",
            )
            alerts += 1
    return alerts


async def check_bill_due_alerts(db: AsyncSession, family_id: int, user_id: int):
    """检查信用账单还款提醒"""
    today = date.today()
    remind_date = today + timedelta(days=3)  # 提前3天提醒

    bills = await db.execute(
        select(CreditCardBill).where(
            CreditCardBill.family_id == family_id,
            CreditCardBill.status.in_(["pending", "partial"]),
            CreditCardBill.due_date <= remind_date,
            CreditCardBill.due_date >= today,
        )
    )
    alerts = 0
    for bill in bills.scalars():
        days_left = (bill.due_date - today).days
        remaining = bill.total_amount - bill.paid_amount
        from app.models.account import PaymentAccount
        acc_result = await db.execute(select(PaymentAccount.name).where(PaymentAccount.id == bill.account_id))
        acc_name = acc_result.scalar() or "信用账户"

        await _send_notification(
            db, family_id, user_id,
            "还款提醒",
            f"{acc_name}还款日还有{days_left}天，待还¥{remaining/100:.2f}",
            "bill_due",
            related_id=bill.id,
            related_type="credit_bill",
        )
        alerts += 1
    return alerts


async def check_large_expense_alerts(db: AsyncSession, family_id: int, user_id: int,
                                      threshold: int = DEFAULT_LARGE_EXPENSE_THRESHOLD):
    """检查今日大额支出"""
    today_start = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)

    result = await db.execute(
        select(Transaction).where(
            Transaction.family_id == family_id,
            Transaction.entry_side == "debit",
            Transaction.is_deleted == False,
            Transaction.type == "expense",
            Transaction.amount >= threshold,
            Transaction.transaction_time >= today_start,
        )
    )
    alerts = 0
    for txn in result.scalars():
        await _send_notification(
            db, family_id, user_id,
            "大额支出提醒",
            f"检测到大额支出：¥{txn.amount/100:.2f} {txn.merchant_name or txn.description or ''}",
            "large_expense",
            related_id=txn.id,
            related_type="transaction",
        )
        alerts += 1
    return alerts


async def check_no_transaction_alerts(db: AsyncSession, family_id: int, user_id: int,
                                       days: int = DEFAULT_NO_TRANSACTION_DAYS):
    """检查连续无交易记录"""
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)

    result = await db.execute(
        select(func.count()).select_from(Transaction).where(
            Transaction.family_id == family_id,
            Transaction.is_deleted == False,
            Transaction.transaction_time >= cutoff,
        )
    )
    count = result.scalar() or 0

    if count == 0:
        await _send_notification(
            db, family_id, user_id,
            "记账提醒",
            f"已经{days}天没有记账了，别忘了记录日常开支哦",
            "no_transaction",
            related_type="reminder",
        )
        return 1
    return 0


async def process_notifications(db: AsyncSession, family_id: int, user_id: int) -> dict:
    """处理一个家庭的所有提醒通知检查"""
    results = {}

    results["budget_alerts"] = await check_budget_alerts(db, family_id, user_id)
    results["bill_due_alerts"] = await check_bill_due_alerts(db, family_id, user_id)
    results["large_expense_alerts"] = await check_large_expense_alerts(db, family_id, user_id)
    results["no_transaction_alerts"] = await check_no_transaction_alerts(db, family_id, user_id)

    await db.commit()
    return results


async def run_notify_job():
    """定时任务：处理所有家庭的提醒通知"""
    from app.database import async_session

    async with async_session() as db:
        result = await db.execute(select(Family))
        families = result.scalars().all()

        total_alerts = 0
        for family in families:
            try:
                results = await process_notifications(db, family.id, family.created_by)
                total_alerts += sum(results.values())
            except Exception as e:
                logger.error("notify_job_error", family_id=family.id, error=str(e))

        logger.info("notify_job_complete", families=len(families), alerts=total_alerts)
        return total_alerts
