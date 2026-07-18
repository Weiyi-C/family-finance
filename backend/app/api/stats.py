from datetime import date, datetime, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy import and_, case, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.database import get_db
from app.models.transaction import Transaction
from app.models.user import User
from app.schemas.stats import (
    AccountStats,
    CategoryStats,
    DailyStats,
    MerchantRank,
    MonthlyStats,
    StatsSummary,
)

router = APIRouter(prefix="/api/stats", tags=["统计分析"])


def _base_conditions(family_id: int, start: str | None, end: str | None, book_id: int | None):
    conds = [
        Transaction.family_id == family_id,
        Transaction.entry_side == "debit",
        Transaction.is_deleted == False,
    ]
    if start:
        conds.append(Transaction.transaction_time >= datetime.fromisoformat(start))
    if end:
        conds.append(Transaction.transaction_time <= datetime.fromisoformat(end))
    if book_id:
        conds.append(Transaction.book_id == book_id)
    return conds


@router.get("/summary", response_model=StatsSummary)
async def get_summary(
    start: str | None = None,
    end: str | None = None,
    book_id: int | None = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    conds = _base_conditions(current_user.family_id, start, end, book_id)

    result = await db.execute(
        select(
            func.coalesce(func.sum(case((Transaction.type == "expense", Transaction.amount), else_=0)), 0).label("total_expense"),
            func.coalesce(func.sum(case((Transaction.type == "income", Transaction.amount), else_=0)), 0).label("total_income"),
            func.count().label("count"),
        ).where(and_(*conds))
    )
    row = result.one()
    return StatsSummary(
        total_expense=row.total_expense,
        total_income=row.total_income,
        net=row.total_income - row.total_expense,
        count=row.count,
    )


@router.get("/by-category", response_model=list[CategoryStats])
async def get_by_category(
    start: str | None = None,
    end: str | None = None,
    type: str = "expense",
    book_id: int | None = None,
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    conds = _base_conditions(current_user.family_id, start, end, book_id)
    conds.append(Transaction.type == type)
    conds.append(Transaction.category_id.isnot(None))

    result = await db.execute(
        select(
            Transaction.category_id,
            func.sum(Transaction.amount).label("total"),
            func.count().label("count"),
        )
        .where(and_(*conds))
        .group_by(Transaction.category_id)
        .order_by(func.sum(Transaction.amount).desc())
        .limit(limit)
    )
    return [
        CategoryStats(category_id=r.category_id, total=r.total, count=r.count)
        for r in result.all()
    ]


@router.get("/by-month", response_model=list[MonthlyStats])
async def get_by_month(
    year: int | None = None,
    type: str | None = None,
    book_id: int | None = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    conds = [
        Transaction.family_id == current_user.family_id,
        Transaction.entry_side == "debit",
        Transaction.is_deleted == False,
    ]
    if year:
        conds.append(func.extract("year", Transaction.transaction_time) == year)
    if type:
        conds.append(Transaction.type == type)
    if book_id:
        conds.append(Transaction.book_id == book_id)

    month_expr = func.date_trunc("month", Transaction.transaction_time).label("month")
    result = await db.execute(
        select(
            month_expr,
            func.coalesce(func.sum(case((Transaction.type == "expense", Transaction.amount), else_=0)), 0).label("expense"),
            func.coalesce(func.sum(case((Transaction.type == "income", Transaction.amount), else_=0)), 0).label("income"),
        )
        .where(and_(*conds))
        .group_by(month_expr)
        .order_by(month_expr)
    )
    return [
        MonthlyStats(month=str(r.month.date()), expense=r.expense, income=r.income)
        for r in result.all()
    ]


@router.get("/by-day", response_model=list[DailyStats])
async def get_by_day(
    start: str | None = None,
    end: str | None = None,
    type: str = "expense",
    book_id: int | None = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    conds = _base_conditions(current_user.family_id, start, end, book_id)
    conds.append(Transaction.type == type)

    day_expr = func.date_trunc("day", Transaction.transaction_time).label("day")
    result = await db.execute(
        select(
            day_expr,
            func.sum(Transaction.amount).label("total"),
            func.count().label("count"),
        )
        .where(and_(*conds))
        .group_by(day_expr)
        .order_by(day_expr)
    )
    return [
        DailyStats(date=str(r.day.date()), total=r.total, count=r.count)
        for r in result.all()
    ]


@router.get("/merchant-ranking", response_model=list[MerchantRank])
async def get_merchant_ranking(
    start: str | None = None,
    end: str | None = None,
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    conds = _base_conditions(current_user.family_id, start, end, None)
    conds.append(Transaction.type == "expense")
    conds.append(Transaction.merchant_name.isnot(None))

    result = await db.execute(
        select(
            Transaction.merchant_name,
            func.sum(Transaction.amount).label("total"),
            func.count().label("count"),
        )
        .where(and_(*conds))
        .group_by(Transaction.merchant_name)
        .order_by(func.sum(Transaction.amount).desc())
        .limit(limit)
    )
    return [
        MerchantRank(merchant=r.merchant_name, total=r.total, count=r.count)
        for r in result.all()
    ]


@router.get("/compare")
async def get_comparison(
    current: str = Query(..., description="当期日期范围，如 2026-07-01:2026-07-31"),
    previous: str = Query(..., description="对比日期范围，如 2026-06-01:2026-06-30"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """同比/环比统计"""
    cur_start, cur_end = current.split(":")
    prev_start, prev_end = previous.split(":")

    async def get_period_stats(start: str, end: str):
        conds = _base_conditions(current_user.family_id, start, end, None)
        result = await db.execute(
            select(
                func.sum(case((Transaction.type == "expense", Transaction.amount), else_=0)).label("expense"),
                func.sum(case((Transaction.type == "income", Transaction.amount), else_=0)).label("income"),
                func.count().label("count"),
            ).where(and_(*conds))
        )
        row = result.one()
        return {
            "expense": row.expense or 0,
            "income": row.income or 0,
            "net": (row.income or 0) - (row.expense or 0),
            "count": row.count or 0,
        }

    current_stats = await get_period_stats(cur_start, cur_end)
    previous_stats = await get_period_stats(prev_start, prev_end)

    # 计算变化率
    def calc_change(curr: int, prev: int):
        if prev == 0:
            return None if curr == 0 else 100.0
        return round((curr - prev) / prev * 100, 2)

    return {
        "current": current_stats,
        "previous": previous_stats,
        "changes": {
            "expense_change": calc_change(current_stats["expense"], previous_stats["expense"]),
            "income_change": calc_change(current_stats["income"], previous_stats["income"]),
            "net_change": calc_change(current_stats["net"], previous_stats["net"]),
            "count_change": calc_change(current_stats["count"], previous_stats["count"]),
        },
    }


@router.get("/cross")
async def get_cross_analysis(
    dimension1: str = Query("category", description="维度1: category/account/channel/platform"),
    dimension2: str = Query("month", description="维度2: month/day/weekday"),
    start: str | None = None,
    end: str | None = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """三维交叉分析"""
    conds = _base_conditions(current_user.family_id, start, end, None)
    conds.append(Transaction.type == "expense")

    # 维度1字段映射
    dim1_map = {
        "category": Transaction.category_id,
        "account": Transaction.payment_account_id,
        "channel": Transaction.payment_channel_id,
        "platform": Transaction.platform_id,
    }
    # 维度2字段映射
    dim2_map = {
        "month": func.to_char(Transaction.transaction_time, "YYYY-MM"),
        "day": func.to_char(Transaction.transaction_time, "YYYY-MM-DD"),
        "weekday": func.extract("dow", Transaction.transaction_time),
    }

    dim1_col = dim1_map.get(dimension1, Transaction.category_id)
    dim2_col = dim2_map.get(dimension2, func.to_char(Transaction.transaction_time, "YYYY-MM"))

    result = await db.execute(
        select(
            dim1_col.label("dim1"),
            dim2_col.label("dim2"),
            func.sum(Transaction.amount).label("total"),
            func.count().label("count"),
        )
        .where(and_(*conds))
        .group_by(dim1_col, dim2_col)
        .order_by(dim1_col, dim2_col)
    )

    return [
        {"dim1": str(r.dim1), "dim2": str(r.dim2), "total": r.total, "count": r.count}
        for r in result.all()
    ]
