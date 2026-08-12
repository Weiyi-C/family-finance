"""周期交易自动处理服务"""

import structlog
from datetime import date, timedelta
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.recurring import RecurringTransaction, RecurringTransactionLog
from app.models.transaction import Transaction
from app.models.notification import Notification
from app.models.user import Family

logger = structlog.get_logger()

OVERDUE_THRESHOLD_DAYS = 7


def calc_next_generate(frequency: str, from_date: date, day_of_month: int | None,
                       day_of_week: int | None, interval_value: int) -> date:
    """计算下一个生成日期"""
    from calendar import monthrange

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


async def _create_transaction_from_recurring(
    db: AsyncSession, recurring: RecurringTransaction, scheduled_date: date
) -> int:
    """从周期交易创建实际交易记录，返回 entry_id"""
    from sqlalchemy import text

    result = await db.execute(text("SELECT nextval('transactions_id_seq')"))
    entry_id = result.scalar()

    txn_time = scheduled_date

    debit = Transaction(
        family_id=recurring.family_id,
        book_id=recurring.book_id,
        entry_id=entry_id,
        entry_side="debit",
        type=recurring.type,
        amount=recurring.amount,
        currency=recurring.currency,
        category_id=recurring.category_id,
        sub_category_id=recurring.sub_category_id,
        payment_account_id=recurring.payment_account_id,
        payment_channel_id=recurring.payment_channel_id,
        platform_id=recurring.platform_id,
        merchant_name=recurring.merchant_name,
        description=f"[自动] {recurring.description or recurring.merchant_name or ''}",
        transaction_time=txn_time,
        recorded_by=recurring.created_by,
    )
    credit = Transaction(
        family_id=recurring.family_id,
        book_id=recurring.book_id,
        entry_id=entry_id,
        entry_side="credit",
        type=recurring.type,
        amount=recurring.amount,
        currency=recurring.currency,
        payment_account_id=recurring.payment_account_id,
        transaction_time=txn_time,
        recorded_by=recurring.created_by,
    )
    db.add(debit)
    db.add(credit)
    return entry_id


async def _send_notification(db: AsyncSession, family_id: int, user_id: int,
                             title: str, content: str, notif_type: str = "recurring_remind"):
    """发送通知"""
    notif = Notification(
        family_id=family_id,
        user_id=user_id,
        type=notif_type,
        title=title,
        content=content,
        related_type="recurring",
    )
    db.add(notif)


async def process_recurring(db: AsyncSession, family_id: int):
    """处理一个家庭的所有周期交易

    逻辑：
    1. next_generate <= 今天的活跃周期交易
    2. auto_create=true → 自动生成交易 + 通知确认
    3. auto_create=false → 发送提醒通知
    4. 逾期 > 7天未确认 → 标记异常
    """
    today = date.today()

    result = await db.execute(
        select(RecurringTransaction).where(
            RecurringTransaction.family_id == family_id,
            RecurringTransaction.is_active == True,
            RecurringTransaction.next_generate <= today,
        )
    )
    recurrings = result.scalars().all()

    processed = 0
    for recurring in recurrings:
        scheduled = recurring.next_generate
        if not scheduled:
            continue

        # 检查是否超出结束日期
        if recurring.end_date and scheduled > recurring.end_date:
            recurring.is_active = False
            continue

        # 检查是否已生成过（避免重复）
        existing_log = await db.execute(
            select(RecurringTransactionLog).where(
                RecurringTransactionLog.recurring_id == recurring.id,
                RecurringTransactionLog.scheduled_date == scheduled,
            )
        )
        if existing_log.scalar_one_or_none():
            # 已有记录，推进到下一个日期
            recurring.next_generate = calc_next_generate(
                recurring.frequency, scheduled,
                recurring.day_of_month, recurring.day_of_week,
                recurring.interval_value,
            )
            if recurring.end_date and recurring.next_generate > recurring.end_date:
                recurring.is_active = False
            continue

        # 自动创建模式
        entry_id = await _create_transaction_from_recurring(db, recurring, scheduled)

        log = RecurringTransactionLog(
            recurring_id=recurring.id,
            scheduled_date=scheduled,
            actual_date=today,
            status="generated",
            amount=recurring.amount,
            transaction_id=entry_id,
        )
        db.add(log)

        recurring.last_generated = today
        recurring.total_generated += 1
        recurring.next_generate = calc_next_generate(
            recurring.frequency, scheduled,
            recurring.day_of_month, recurring.day_of_week,
            recurring.interval_value,
        )
        if recurring.end_date and recurring.next_generate > recurring.end_date:
            recurring.is_active = False

        # 发送确认通知
        amount_yuan = f"¥{recurring.amount / 100:.2f}"
        desc = recurring.description or recurring.merchant_name or "周期交易"
        await _send_notification(
            db, family_id, recurring.created_by,
            "周期交易已自动生成",
            f"{desc} {amount_yuan}（{scheduled}）已自动创建",
            "recurring_generated",
        )

        processed += 1
        logger.info("recurring_auto_generated",
                     recurring_id=recurring.id, scheduled=scheduled, entry_id=entry_id)

    # 检查逾期的周期交易（next_generate 过期但没有日志记录）
    overdue_date = today - timedelta(days=OVERDUE_THRESHOLD_DAYS)
    overdue_result = await db.execute(
        select(RecurringTransaction).where(
            RecurringTransaction.family_id == family_id,
            RecurringTransaction.is_active == True,
            RecurringTransaction.next_generate <= overdue_date,
        )
    )
    for recurring in overdue_result.scalars():
        # 检查是否有对应的日志
        log_exists = await db.execute(
            select(RecurringTransactionLog).where(
                RecurringTransactionLog.recurring_id == recurring.id,
                RecurringTransactionLog.scheduled_date == recurring.next_generate,
            )
        )
        if not log_exists.scalar_one_or_none():
            # 标记为逾期
            log = RecurringTransactionLog(
                recurring_id=recurring.id,
                scheduled_date=recurring.next_generate,
                status="overdue",
                amount=recurring.amount,
                note=f"逾期{OVERDUE_THRESHOLD_DAYS}天未处理",
            )
            db.add(log)

            amount_yuan = f"¥{recurring.amount / 100:.2f}"
            desc = recurring.description or recurring.merchant_name or "周期交易"
            await _send_notification(
                db, family_id, recurring.created_by,
                "周期交易逾期提醒",
                f"{desc} {amount_yuan}（{recurring.next_generate}）已逾期，请检查",
                "recurring_overdue",
            )

    await db.commit()
    return processed


async def run_recurring_job():
    """定时任务：处理所有家庭的周期交易"""
    from app.database import async_session

    async with async_session() as db:
        result = await db.execute(select(Family))
        families = result.scalars().all()

        total = 0
        for family in families:
            try:
                count = await process_recurring(db, family.id)
                total += count
            except Exception as e:
                logger.error("recurring_job_error", family_id=family.id, error=str(e))

        logger.info("recurring_job_complete", families=len(families), processed=total)
        return total
