"""process 阶段 — 交易后处理流水线

交易创建/删除后自动执行：
1. 信用账单更新
2. 预算检查（超支则发通知）
3. 自动化规则执行（process 阶段规则）
"""

import calendar
from datetime import datetime, timezone
from typing import Literal

import structlog
from sqlalchemy import and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.account import PaymentAccount
from app.models.budget import Budget
from app.models.category import Category
from app.models.credit_bill import CreditCardBill
from app.models.notification import Notification
from app.models.rule import AutomationRule
from app.models.transaction import Transaction

logger = structlog.get_logger()

# 信用账户类型
CREDIT_TYPES = ["bank_credit", "alipay_huabei", "alipay_jiebei", "jd_baitiao", "meituan_monthly"]


async def run_process_pipeline(
    db: AsyncSession,
    family_id: int,
    user_id: int,
    event: Literal["created", "deleted"],
    txn_type: str,
    account_id: int | None,
    category_id: int | None,
    amount: int,
    txn_time: datetime,
):
    """交易后处理流水线

    Args:
        db: 数据库会话
        family_id: 家庭ID
        user_id: 操作用户ID
        event: 事件类型 (created/deleted)
        txn_type: 交易类型 (expense/income/transfer)
        account_id: 账户ID
        category_id: 分类ID
        amount: 金额（分）
        txn_time: 交易时间
    """
    results = {}

    # 1. 信用账单更新
    if txn_type == "expense" and account_id:
        bill_updated = await _update_credit_bill(db, family_id, account_id, txn_time)
        if bill_updated:
            results["credit_bill"] = True

    # 2. 预算检查（仅支出交易创建时）
    if event == "created" and txn_type == "expense":
        budget_alert = await _check_budget_after_expense(db, family_id, user_id, category_id, amount, txn_time)
        if budget_alert:
            results["budget_alert"] = True

    # 3. 自动化规则执行（process 阶段）
    rule_results = await _execute_process_rules(db, family_id, event, txn_type, account_id, category_id, amount)
    if rule_results:
        results["rules"] = rule_results

    if results:
        await db.commit()

    return results


async def _update_credit_bill(db: AsyncSession, family_id: int, account_id: int, txn_time: datetime) -> bool:
    """更新信用账单（复用现有逻辑）"""
    from app.api.credit_bills import auto_update_credit_bill
    try:
        await auto_update_credit_bill(db, family_id, account_id, txn_time)
        return True
    except Exception as e:
        logger.error("process_credit_bill_error", error=str(e))
        return False


async def _check_budget_after_expense(
    db: AsyncSession, family_id: int, user_id: int,
    category_id: int | None, amount: int, txn_time: datetime,
) -> bool:
    """支出后检查预算是否超支"""
    if not category_id:
        return False

    now = txn_time
    budgets = await db.execute(
        select(Budget).where(
            Budget.family_id == family_id,
            Budget.period == "monthly",
            Budget.year == now.year,
            Budget.month == now.month,
            or_(Budget.category_id == category_id, Budget.category_id.is_(None)),
        )
    )

    for budget in budgets.scalars():
        # 计算该分类本月已花费
        start = datetime(now.year, now.month, 1, tzinfo=timezone.utc)
        _, last_day = calendar.monthrange(now.year, now.month)
        end = datetime(now.year, now.month, last_day, 23, 59, 59, tzinfo=timezone.utc)

        conds = [
            Transaction.family_id == family_id,
            Transaction.entry_side == "debit",
            Transaction.is_deleted == False,
            Transaction.type == "expense",
            Transaction.transaction_time >= start,
            Transaction.transaction_time <= end,
        ]
        if budget.category_id:
            conds.append(Transaction.category_id == budget.category_id)

        result = await db.execute(
            select(func.coalesce(func.sum(Transaction.amount), 0)).where(and_(*conds))
        )
        spent = result.scalar() or 0
        total = budget.amount + budget.rollover_amount

        if total > 0 and spent >= total * budget.alert_threshold:
            percent = int(spent / total * 100)
            cat_name = "总预算"
            if budget.category_id:
                cat_result = await db.execute(select(Category.name).where(Category.id == budget.category_id))
                cat_name = cat_result.scalar() or "未知分类"

            # 检查今天是否已发过预算通知
            today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
            existing = await db.execute(
                select(Notification).where(
                    Notification.family_id == family_id,
                    Notification.type == "budget_alert",
                    Notification.related_id == budget.id,
                    Notification.created_at >= today_start,
                ).limit(1)
            )
            if not existing.scalar_one_or_none():
                notif = Notification(
                    family_id=family_id,
                    user_id=user_id,
                    type="budget_alert",
                    title="预算预警",
                    content=f"{cat_name}本月支出已达预算的{percent}%（¥{spent/100:.0f}/¥{total/100:.0f}）",
                    related_id=budget.id,
                    related_type="budget",
                )
                db.add(notif)
                logger.info("budget_alert_sent", family_id=family_id, budget_id=budget.id, percent=percent)
                return True

    return False


async def _execute_process_rules(
    db: AsyncSession, family_id: int,
    event: str, txn_type: str,
    account_id: int | None, category_id: int | None, amount: int,
) -> list[dict]:
    """执行 process 阶段的自动化规则"""
    result = await db.execute(
        select(AutomationRule).where(
            AutomationRule.is_active == True,
            or_(AutomationRule.family_id == family_id, AutomationRule.family_id.is_(None)),
            AutomationRule.stage == "process",
        ).order_by(AutomationRule.priority.desc())
    )
    rules = result.scalars().all()
    executed = []

    for rule in rules:
        conditions = rule.conditions or {}
        actions = rule.actions or {}

        # 匹配条件
        if not _match_process_conditions(conditions, event, txn_type, account_id, category_id, amount):
            continue

        # 执行动作
        action_result = await _execute_process_actions(db, family_id, actions, account_id, category_id, amount)
        if action_result:
            rule.hit_count += 1
            executed.append({"rule_id": rule.id, "rule_name": rule.name, "result": action_result})

    return executed


def _match_process_conditions(
    conditions: dict, event: str, txn_type: str,
    account_id: int | None, category_id: int | None, amount: int,
) -> bool:
    """匹配 process 阶段规则条件"""
    # 事件类型匹配
    expected_event = conditions.get("event")
    if expected_event and expected_event != event:
        return False

    # 交易类型匹配
    expected_type = conditions.get("txn_type")
    if expected_type and expected_type != txn_type:
        return False

    # 最小金额匹配
    amount_min = conditions.get("amount_min")
    if amount_min and amount < amount_min:
        return False

    # 账户类型匹配
    account_type = conditions.get("account_type")
    # 注意：这里需要查询账户类型，但为了简化先跳过
    # 后续可以通过传入 account_type 参数来支持

    return True


async def _execute_process_actions(
    db: AsyncSession, family_id: int, actions: dict,
    account_id: int | None, category_id: int | None, amount: int,
) -> dict | None:
    """执行 process 阶段规则动作"""
    results = {}

    # 更新预算
    if actions.get("update_budget"):
        results["update_budget"] = True
        # 预算已经在 _check_budget_after_expense 中处理

    # 发送通知
    if actions.get("notify"):
        content = actions.get("notify_content", "规则触发通知")
        # 替换变量
        content = content.replace("{amount}", f"¥{amount/100:.2f}")
        notif = Notification(
            family_id=family_id,
            user_id=0,  # 系统通知
            type="rule_notify",
            title=actions.get("notify_title", "规则通知"),
            content=content,
            related_type="automation_rule",
        )
        db.add(notif)
        results["notify"] = True

    return results if results else None
