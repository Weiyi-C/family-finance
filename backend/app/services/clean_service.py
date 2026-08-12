"""clean 阶段 — 数据质量检查

定期扫描交易数据，发现质量问题通知用户：
1. 疑似重复交易（同日同商户同金额）
2. 缺失字段（无分类/无商户名）
3. 异常金额（0或负数）
"""

from datetime import datetime, timedelta, timezone

import structlog
from sqlalchemy import and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.category import Category
from app.models.notification import Notification
from app.models.tag import Tag
from app.models.transaction import Transaction
from app.models.transaction_tag import TransactionTag
from app.models.user import Family

logger = structlog.get_logger()

# 默认扫描最近30天
DEFAULT_WINDOW_DAYS = 30
# 疑似重复交易最小金额（分），忽略小额
DUPLICATE_MIN_AMOUNT = 100


async def check_duplicate_transactions(db: AsyncSession, family_id: int, window_days: int = DEFAULT_WINDOW_DAYS) -> list[dict]:
    """检测疑似重复交易：同日同商户同金额"""
    cutoff = datetime.now(timezone.utc) - timedelta(days=window_days)

    # 按日期+商户+金额分组，找出出现多次的组合
    result = await db.execute(
        select(
            func.date_trunc("day", Transaction.transaction_time).label("day"),
            Transaction.merchant_name,
            Transaction.amount,
            func.count().label("cnt"),
            func.array_agg(Transaction.id).label("ids"),
        ).where(
            Transaction.family_id == family_id,
            Transaction.entry_side == "debit",
            Transaction.is_deleted == False,
            Transaction.type.in_(["expense", "income"]),
            Transaction.transaction_time >= cutoff,
            Transaction.amount >= DUPLICATE_MIN_AMOUNT,
            Transaction.merchant_name.isnot(None),
            Transaction.merchant_name != "",
        ).group_by(
            func.date_trunc("day", Transaction.transaction_time),
            Transaction.merchant_name,
            Transaction.amount,
        ).having(func.count() > 1)
    )

    duplicates = []
    for row in result.all():
        duplicates.append({
            "date": row.day.strftime("%Y-%m-%d") if row.day else "",
            "merchant": row.merchant_name,
            "amount": row.amount,
            "count": row.cnt,
            "ids": row.ids,
        })

    return duplicates


async def check_missing_fields(db: AsyncSession, family_id: int, window_days: int = DEFAULT_WINDOW_DAYS) -> dict:
    """检测缺失字段的交易"""
    cutoff = datetime.now(timezone.utc) - timedelta(days=window_days)

    base_conds = [
        Transaction.family_id == family_id,
        Transaction.entry_side == "debit",
        Transaction.is_deleted == False,
        Transaction.type.in_(["expense", "income"]),
        Transaction.transaction_time >= cutoff,
    ]

    # 无分类
    no_cat = await db.execute(
        select(func.count()).select_from(Transaction).where(
            *base_conds, Transaction.category_id.is_(None)
        )
    )
    no_category_count = no_cat.scalar() or 0

    # 无商户名
    no_merchant = await db.execute(
        select(func.count()).select_from(Transaction).where(
            *base_conds,
            or_(Transaction.merchant_name.is_(None), Transaction.merchant_name == "")
        )
    )
    no_merchant_count = no_merchant.scalar() or 0

    # 无标签（关联查询）
    txn_ids_result = await db.execute(
        select(Transaction.id).where(and_(*base_conds))
    )
    all_ids = [r[0] for r in txn_ids_result.all()]

    no_tag_count = 0
    if all_ids:
        tagged_result = await db.execute(
            select(TransactionTag.transaction_id).where(
                TransactionTag.transaction_id.in_(all_ids)
            ).distinct()
        )
        tagged_ids = set(r[0] for r in tagged_result.all())
        no_tag_count = len(all_ids) - len(tagged_ids)

    return {
        "no_category": no_category_count,
        "no_merchant": no_merchant_count,
        "no_tag": no_tag_count,
        "total_checked": len(all_ids),
    }


async def check_abnormal_amounts(db: AsyncSession, family_id: int, window_days: int = DEFAULT_WINDOW_DAYS) -> list[dict]:
    """检测异常金额（0或负数）"""
    cutoff = datetime.now(timezone.utc) - timedelta(days=window_days)

    result = await db.execute(
        select(Transaction).where(
            Transaction.family_id == family_id,
            Transaction.entry_side == "debit",
            Transaction.is_deleted == False,
            Transaction.transaction_time >= cutoff,
            Transaction.amount <= 0,
        ).order_by(Transaction.transaction_time.desc()).limit(50)
    )

    abnormal = []
    for txn in result.scalars():
        abnormal.append({
            "id": txn.id,
            "time": txn.transaction_time.strftime("%Y-%m-%d %H:%M") if txn.transaction_time else "",
            "merchant": txn.merchant_name or "",
            "amount": txn.amount,
        })

    return abnormal


async def run_clean_checks(db: AsyncSession, family_id: int, user_id: int, window_days: int = DEFAULT_WINDOW_DAYS) -> dict:
    """执行所有数据质量检查并发送通知"""
    results = {}

    # 1. 疑似重复交易
    duplicates = await check_duplicate_transactions(db, family_id, window_days)
    results["duplicates"] = len(duplicates)
    if duplicates:
        # 只通知前5条
        examples = duplicates[:5]
        detail = "、".join(
            f"{d['date']} {d['merchant']} ¥{d['amount']/100:.0f}×{d['count']}"
            for d in examples
        )
        suffix = f"等{len(duplicates)}组" if len(duplicates) > 5 else ""
        notif = Notification(
            family_id=family_id,
            user_id=user_id,
            type="clean_duplicate",
            title="疑似重复交易",
            content=f"发现{len(duplicates)}组疑似重复交易：{detail}{suffix}",
            related_type="clean",
        )
        db.add(notif)

    # 2. 缺失字段
    missing = await check_missing_fields(db, family_id, window_days)
    results["missing"] = missing
    total_missing = missing["no_category"] + missing["no_merchant"]
    if total_missing > 0:
        parts = []
        if missing["no_category"] > 0:
            parts.append(f"{missing['no_category']}条无分类")
        if missing["no_merchant"] > 0:
            parts.append(f"{missing['no_merchant']}条无商户名")
        if missing["no_tag"] > 0:
            parts.append(f"{missing['no_tag']}条无标签")
        notif = Notification(
            family_id=family_id,
            user_id=user_id,
            type="clean_missing",
            title="数据不完整",
            content=f"最近{window_days}天有{', '.join(parts)}的交易",
            related_type="clean",
        )
        db.add(notif)

    # 3. 异常金额
    abnormal = await check_abnormal_amounts(db, family_id, window_days)
    results["abnormal_amounts"] = len(abnormal)
    if abnormal:
        notif = Notification(
            family_id=family_id,
            user_id=user_id,
            type="clean_abnormal",
            title="异常金额",
            content=f"发现{len(abnormal)}条金额为0或负数的交易",
            related_type="clean",
        )
        db.add(notif)

    await db.commit()
    return results


async def run_clean_job():
    """定时任务：执行所有家庭的数据质量检查"""
    from app.database import async_session

    async with async_session() as db:
        result = await db.execute(select(Family))
        families = result.scalars().all()

        total_issues = 0
        for family in families:
            try:
                results = await run_clean_checks(db, family.id, family.created_by)
                issues = results.get("duplicates", 0) + results.get("abnormal_amounts", 0)
                missing = results.get("missing", {})
                issues += missing.get("no_category", 0) + missing.get("no_merchant", 0)
                total_issues += issues
            except Exception as e:
                logger.error("clean_job_error", family_id=family.id, error=str(e))

        logger.info("clean_job_complete", families=len(families), issues=total_issues)
        return total_issues
