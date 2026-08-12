"""analyze 阶段 — 统计级分析洞察

后台分析消费模式，生成统计级洞察：
1. 消费趋势：本月支出同比/环比变化
2. 分类异常：某分类支出突然增加50%以上
3. 高频商户：Top10消费商户排行
4. 储蓄建议：根据消费模式给出储蓄建议
"""

import calendar
from datetime import date, datetime, timedelta, timezone

import structlog
from sqlalchemy import and_, case, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.category import Category
from app.models.insight import Insight
from app.models.notification import Notification
from app.models.transaction import Transaction
from app.models.user import Family

logger = structlog.get_logger()

# 分类异常阈值（环比增长超过此比例触发）
SPIKE_THRESHOLD = 0.5
# 环比变化阈值
TREND_THRESHOLD = 0.3


def _month_range(year: int, month: int):
    """获取月份的起止日期"""
    start = datetime(year, month, 1, tzinfo=timezone.utc)
    _, last_day = calendar.monthrange(year, month)
    end = datetime(year, month, last_day, 23, 59, 59, tzinfo=timezone.utc)
    return start, end


def _prev_month(year: int, month: int):
    """获取上一个月"""
    if month == 1:
        return year - 1, 12
    return year, month - 1


async def _get_month_expense(db: AsyncSession, family_id: int, year: int, month: int) -> int:
    """获取某月总支出"""
    start, end = _month_range(year, month)
    result = await db.execute(
        select(func.coalesce(func.sum(Transaction.amount), 0)).where(
            Transaction.family_id == family_id,
            Transaction.entry_side == "debit",
            Transaction.is_deleted == False,
            Transaction.type == "expense",
            Transaction.transaction_time >= start,
            Transaction.transaction_time <= end,
        )
    )
    return result.scalar() or 0


async def _get_category_expenses(db: AsyncSession, family_id: int, year: int, month: int) -> dict[int, int]:
    """获取某月各分类支出"""
    start, end = _month_range(year, month)
    result = await db.execute(
        select(
            Transaction.category_id,
            func.sum(Transaction.amount).label("total"),
        ).where(
            Transaction.family_id == family_id,
            Transaction.entry_side == "debit",
            Transaction.is_deleted == False,
            Transaction.type == "expense",
            Transaction.transaction_time >= start,
            Transaction.transaction_time <= end,
            Transaction.category_id.isnot(None),
        ).group_by(Transaction.category_id)
    )
    return {r.category_id: r.total for r in result.all()}


async def _get_category_names(db: AsyncSession, family_id: int) -> dict[int, str]:
    """获取分类名称映射"""
    result = await db.execute(
        select(Category.id, Category.name).where(
            or_(Category.family_id == family_id, Category.family_id.is_(None))
        )
    )
    return {r.id: r.name for r in result.all()}


async def analyze_trends(db: AsyncSession, family_id: int) -> list[dict]:
    """分析消费趋势：环比变化"""
    now = datetime.now()
    cur_year, cur_month = now.year, now.month
    prev_year, prev_month = _prev_month(cur_year, cur_month)

    cur_expense = await _get_month_expense(db, family_id, cur_year, cur_month)
    prev_expense = await _get_month_expense(db, family_id, prev_year, prev_month)

    insights = []

    if prev_expense > 0:
        change = (cur_expense - prev_expense) / prev_expense
        if abs(change) >= TREND_THRESHOLD:
            direction = "增加" if change > 0 else "减少"
            percent = abs(int(change * 100))
            insight = {
                "type": "trend_alert",
                "title": f"本月支出环比{direction}{percent}%",
                "content": f"本月（{cur_month}月）支出¥{cur_expense/100:.0f}，上月（{prev_month}月）支出¥{prev_expense/100:.0f}，环比{direction}{percent}%",
                "data": {
                    "current_month": f"{cur_year}-{cur_month:02d}",
                    "previous_month": f"{prev_year}-{prev_month:02d}",
                    "current_expense": cur_expense,
                    "previous_expense": prev_expense,
                    "change_percent": round(change * 100, 1),
                },
            }
            insights.append(insight)

    return insights


async def analyze_category_spikes(db: AsyncSession, family_id: int) -> list[dict]:
    """分析分类异常：某分类支出环比大幅增加"""
    now = datetime.now()
    cur_year, cur_month = now.year, now.month
    prev_year, prev_month = _prev_month(cur_year, cur_month)

    cur_cats = await _get_category_expenses(db, family_id, cur_year, cur_month)
    prev_cats = await _get_category_expenses(db, family_id, prev_year, prev_month)
    cat_names = await _get_category_names(db, family_id)

    insights = []
    for cat_id, cur_amount in cur_cats.items():
        prev_amount = prev_cats.get(cat_id, 0)
        if prev_amount > 0 and cur_amount > prev_amount:
            change = (cur_amount - prev_amount) / prev_amount
            if change >= SPIKE_THRESHOLD:
                cat_name = cat_names.get(cat_id, f"分类{cat_id}")
                percent = int(change * 100)
                insights.append({
                    "type": "category_spike",
                    "title": f"{cat_name}支出异常增长{percent}%",
                    "content": f"本月{cat_name}支出¥{cur_amount/100:.0f}，上月¥{prev_amount/100:.0f}，增长{percent}%",
                    "data": {
                        "category_id": cat_id,
                        "category_name": cat_name,
                        "current_amount": cur_amount,
                        "previous_amount": prev_amount,
                        "change_percent": round(change * 100, 1),
                    },
                })

    return insights


async def analyze_merchant_ranking(db: AsyncSession, family_id: int) -> list[dict]:
    """分析高频商户：本月Top10消费商户"""
    now = datetime.now()
    start, end = _month_range(now.year, now.month)

    result = await db.execute(
        select(
            Transaction.merchant_name,
            func.sum(Transaction.amount).label("total"),
            func.count().label("count"),
        ).where(
            Transaction.family_id == family_id,
            Transaction.entry_side == "debit",
            Transaction.is_deleted == False,
            Transaction.type == "expense",
            Transaction.transaction_time >= start,
            Transaction.transaction_time <= end,
            Transaction.merchant_name.isnot(None),
            Transaction.merchant_name != "",
        ).group_by(Transaction.merchant_name)
        .order_by(func.sum(Transaction.amount).desc())
        .limit(10)
    )

    merchants = []
    for r in result.all():
        merchants.append({
            "merchant": r.merchant_name,
            "total": r.total,
            "count": r.count,
        })

    if not merchants:
        return []

    # 生成摘要
    top3 = merchants[:3]
    top3_text = "、".join(f"{m['merchant']}(¥{m['total']/100:.0f})" for m in top3)

    return [{
        "type": "merchant_rank",
        "title": f"本月消费商户Top10",
        "content": f"消费最多的商户：{top3_text}",
        "data": {"merchants": merchants},
    }]


async def analyze_savings_tips(db: AsyncSession, family_id: int) -> list[dict]:
    """储蓄建议：根据消费模式给出建议"""
    now = datetime.now()
    cur_year, cur_month = now.year, now.month
    prev_year, prev_month = _prev_month(cur_year, cur_month)

    cur_expense = await _get_month_expense(db, family_id, cur_year, cur_month)
    prev_expense = await _get_month_expense(db, family_id, prev_year, prev_month)

    insights = []

    # 如果本月支出比上月多，给出建议
    if prev_expense > 0 and cur_expense > prev_expense:
        diff = cur_expense - prev_expense
        # 找出增长最多的分类
        cur_cats = await _get_category_expenses(db, family_id, cur_year, cur_month)
        prev_cats = await _get_category_expenses(db, family_id, prev_year, prev_month)
        cat_names = await _get_category_names(db, family_id)

        max_increase = 0
        max_cat = None
        for cat_id, cur_amt in cur_cats.items():
            prev_amt = prev_cats.get(cat_id, 0)
            increase = cur_amt - prev_amt
            if increase > max_increase:
                max_increase = increase
                max_cat = cat_id

        if max_cat:
            cat_name = cat_names.get(max_cat, f"分类{max_cat}")
            insights.append({
                "type": "savings_tip",
                "title": "消费控制建议",
                "content": f"本月支出比上月多¥{diff/100:.0f}，其中{cat_name}增长最多（+¥{max_increase/100:.0f}）。建议关注{cat_name}类消费。",
                "data": {
                    "diff": diff,
                    "top_increase_category": cat_name,
                    "increase_amount": max_increase,
                },
            })

    return insights


async def run_analyze(db: AsyncSession, family_id: int) -> list[dict]:
    """执行所有分析洞察"""
    all_insights = []

    # 1. 消费趋势
    try:
        trend_insights = await analyze_trends(db, family_id)
        all_insights.extend(trend_insights)
    except Exception as e:
        logger.error("analyze_trends_error", error=str(e))

    # 2. 分类异常
    try:
        spike_insights = await analyze_category_spikes(db, family_id)
        all_insights.extend(spike_insights)
    except Exception as e:
        logger.error("analyze_category_spikes_error", error=str(e))

    # 3. 高频商户
    try:
        merchant_insights = await analyze_merchant_ranking(db, family_id)
        all_insights.extend(merchant_insights)
    except Exception as e:
        logger.error("analyze_merchant_ranking_error", error=str(e))

    # 4. 储蓄建议
    try:
        savings_insights = await analyze_savings_tips(db, family_id)
        all_insights.extend(savings_insights)
    except Exception as e:
        logger.error("analyze_savings_tips_error", error=str(e))

    return all_insights


async def run_analyze_job():
    """定时任务：执行所有家庭的分析洞察"""
    from app.database import async_session

    async with async_session() as db:
        result = await db.execute(select(Family))
        families = result.scalars().all()

        total_insights = 0
        for family in families:
            try:
                insights = await run_analyze(db, family.id)

                for ins in insights:
                    # 保存洞察记录
                    insight = Insight(
                        family_id=family.id,
                        type=ins["type"],
                        title=ins["title"],
                        content=ins["content"],
                        data=ins.get("data"),
                    )
                    db.add(insight)

                    # 发送通知
                    notif = Notification(
                        family_id=family.id,
                        user_id=family.created_by,
                        type="insight",
                        title=ins["title"],
                        content=ins["content"],
                        related_type="insight",
                    )
                    db.add(notif)

                total_insights += len(insights)
                await db.commit()
            except Exception as e:
                logger.error("analyze_job_error", family_id=family.id, error=str(e))

        logger.info("analyze_job_complete", families=len(families), insights=total_insights)
        return total_insights
