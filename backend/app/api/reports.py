"""报表分析 API"""

import calendar
from datetime import date, datetime, timedelta, timezone
from io import BytesIO

import structlog
from fastapi import APIRouter, Depends, Query
from fastapi.responses import StreamingResponse
from sqlalchemy import and_, case, func, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.database import get_db
from app.models.account import PaymentAccount
from app.models.category import Category
from app.models.transaction import Transaction
from app.models.user import User

logger = structlog.get_logger()
router = APIRouter(prefix="/api/reports", tags=["报表分析"])


def _parse_range(start: str | None, end: str | None, year: int | None, month: int | None):
    """解析时间范围，返回 (start_dt, end_dt)"""
    now = datetime.now()
    if start and end:
        return datetime.fromisoformat(start), datetime.fromisoformat(end)
    if year and month:
        _, last_day = calendar.monthrange(year, month)
        return datetime(year, month, 1), datetime(year, month, last_day, 23, 59, 59)
    if year:
        return datetime(year, 1, 1), datetime(year, 12, 31, 23, 59, 59)
    # 默认当月
    _, last_day = calendar.monthrange(now.year, now.month)
    return datetime(now.year, now.month, 1), datetime(now.year, now.month, last_day, 23, 59, 59)


# ===================== 1. 收支报表 =====================

@router.get("/income-expense")
async def income_expense_report(
    start: str | None = None,
    end: str | None = None,
    year: int | None = None,
    group_by: str = Query("month", description="month/quarter/year"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """收支报表：按月/季/年汇总收入支出"""
    start_dt, end_dt = _parse_range(start, end, year, None)
    family_id = current_user.family_id

    conds = [
        Transaction.family_id == family_id,
        Transaction.entry_side == "debit",
        Transaction.is_deleted == False,
        Transaction.transaction_time >= start_dt,
        Transaction.transaction_time <= end_dt,
    ]

    if group_by == "quarter":
        period_expr = func.concat(
            func.extract("year", Transaction.transaction_time).cast(text("TEXT")),
            "Q",
            func.ceil(func.extract("month", Transaction.transaction_time) / 3).cast(text("TEXT")),
        )
    elif group_by == "year":
        period_expr = func.extract("year", Transaction.transaction_time).cast(text("TEXT"))
    else:  # month
        period_expr = func.to_char(Transaction.transaction_time, "YYYY-MM")

    result = await db.execute(
        select(
            period_expr.label("period"),
            func.coalesce(func.sum(case((Transaction.type == "expense", Transaction.amount), else_=0)), 0).label("expense"),
            func.coalesce(func.sum(case((Transaction.type == "income", Transaction.amount), else_=0)), 0).label("income"),
            func.count().label("count"),
        )
        .where(and_(*conds))
        .group_by(period_expr)
        .order_by(period_expr)
    )

    rows = []
    prev_expense = None
    for r in result.all():
        expense_change = None
        income_change = None
        if prev_expense is not None and prev_expense > 0:
            expense_change = round((r.expense - prev_expense) / prev_expense * 100, 1)
        prev_expense = r.expense

        rows.append({
            "period": str(r.period),
            "expense": r.expense,
            "income": r.income,
            "net": r.income - r.expense,
            "count": r.count,
            "expense_change": expense_change,
        })

    total_expense = sum(r["expense"] for r in rows)
    total_income = sum(r["income"] for r in rows)

    return {
        "periods": rows,
        "summary": {
            "total_expense": total_expense,
            "total_income": total_income,
            "net": total_income - total_expense,
            "avg_monthly_expense": total_expense // max(len(rows), 1),
        },
    }


# ===================== 2. 资产负债报表 =====================

@router.get("/balance-sheet")
async def balance_sheet_report(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """资产负债报表：各账户余额汇总"""
    family_id = current_user.family_id

    # 获取所有活跃账户
    accounts = await db.execute(
        select(PaymentAccount).where(
            PaymentAccount.family_id == family_id,
            PaymentAccount.is_active == True,
            PaymentAccount.is_hidden == False,
        )
    )

    assets = []  # 资产账户
    liabilities = []  # 负债账户
    total_assets = 0
    total_liabilities = 0

    for acc in accounts.scalars():
        # 计算余额
        balance_result = await db.execute(
            select(
                func.coalesce(func.sum(
                    case(
                        (Transaction.type.in_(["income"]), Transaction.amount),
                        (Transaction.type == "transfer", case(
                            (Transaction.entry_side == "debit", Transaction.amount),
                            else_=-Transaction.amount,
                        )),
                        else_=-Transaction.amount,
                    )
                ), 0)
            ).where(
                Transaction.payment_account_id == acc.id,
                Transaction.family_id == family_id,
                Transaction.is_deleted == False,
                Transaction.entry_side == "debit",
            )
        )
        txn_sum = balance_result.scalar() or 0
        balance = acc.initial_balance + txn_sum

        item = {
            "id": acc.id,
            "name": acc.name,
            "type_code": acc.type_code,
            "balance": balance,
        }

        if acc.type_code in ("bank_credit", "alipay_huabei", "alipay_jiebei", "jd_baitiao", "meituan_monthly"):
            liabilities.append(item)
            total_liabilities += balance
        else:
            assets.append(item)
            total_assets += balance

    return {
        "assets": assets,
        "liabilities": liabilities,
        "total_assets": total_assets,
        "total_liabilities": total_liabilities,
        "net_worth": total_assets - total_liabilities,
    }


# ===================== 3. 现金流报表 =====================

@router.get("/cash-flow")
async def cash_flow_report(
    start: str | None = None,
    end: str | None = None,
    year: int | None = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """现金流报表：资金流入流出分析"""
    start_dt, end_dt = _parse_range(start, end, year, None)
    family_id = current_user.family_id

    conds = [
        Transaction.family_id == family_id,
        Transaction.entry_side == "debit",
        Transaction.is_deleted == False,
        Transaction.transaction_time >= start_dt,
        Transaction.transaction_time <= end_dt,
    ]

    # 按月汇总
    month_expr = func.to_char(Transaction.transaction_time, "YYYY-MM")
    result = await db.execute(
        select(
            month_expr.label("month"),
            func.coalesce(func.sum(case((Transaction.type == "income", Transaction.amount), else_=0)), 0).label("inflow"),
            func.coalesce(func.sum(case((Transaction.type == "expense", Transaction.amount), else_=0)), 0).label("outflow"),
            func.coalesce(func.sum(case((Transaction.type == "transfer", Transaction.amount), else_=0)), 0).label("transfer"),
        )
        .where(and_(*conds))
        .group_by(month_expr)
        .order_by(month_expr)
    )

    months = []
    for r in result.all():
        months.append({
            "month": str(r.month),
            "inflow": r.inflow,
            "outflow": r.outflow,
            "net_flow": r.inflow - r.outflow,
            "transfer": r.transfer,
        })

    total_inflow = sum(m["inflow"] for m in months)
    total_outflow = sum(m["outflow"] for m in months)

    return {
        "months": months,
        "summary": {
            "total_inflow": total_inflow,
            "total_outflow": total_outflow,
            "net_flow": total_inflow - total_outflow,
            "avg_monthly_outflow": total_outflow // max(len(months), 1),
        },
    }


# ===================== 4. 分类明细报表 =====================

@router.get("/category-detail")
async def category_detail_report(
    start: str | None = None,
    end: str | None = None,
    year: int | None = None,
    month: int | None = None,
    type: str = "expense",
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """分类明细报表：按分类汇总，可展开查看明细"""
    start_dt, end_dt = _parse_range(start, end, year, month)
    family_id = current_user.family_id

    conds = [
        Transaction.family_id == family_id,
        Transaction.entry_side == "debit",
        Transaction.is_deleted == False,
        Transaction.type == type,
        Transaction.transaction_time >= start_dt,
        Transaction.transaction_time <= end_dt,
    ]

    # 分类汇总
    cat_result = await db.execute(
        select(
            Transaction.category_id,
            func.sum(Transaction.amount).label("total"),
            func.count().label("count"),
        )
        .where(and_(*conds))
        .group_by(Transaction.category_id)
        .order_by(func.sum(Transaction.amount).desc())
    )

    # 获取分类名称
    cat_names = {}
    cats = await db.execute(select(Category.id, Category.name).where(
        (Category.family_id == family_id) | (Category.family_id.is_(None))
    ))
    for c in cats.all():
        cat_names[c.id] = c.name

    categories = []
    grand_total = 0
    for r in cat_result.all():
        cat_id = r.category_id
        cat_name = cat_names.get(cat_id, "未分类") if cat_id else "未分类"
        grand_total += r.total

        # 获取该分类下的交易明细
        txn_result = await db.execute(
            select(Transaction).where(
                *conds,
                Transaction.category_id == cat_id if cat_id else Transaction.category_id.is_(None),
            ).order_by(Transaction.transaction_time.desc()).limit(50)
        )
        transactions = []
        for t in txn_result.scalars():
            transactions.append({
                "id": t.id,
                "time": t.transaction_time.strftime("%Y-%m-%d %H:%M") if t.transaction_time else "",
                "merchant": t.merchant_name or "",
                "description": t.description or "",
                "amount": t.amount,
            })

        categories.append({
            "category_id": cat_id,
            "category_name": cat_name,
            "total": r.total,
            "count": r.count,
            "transactions": transactions,
        })

    # 计算占比
    for cat in categories:
        cat["percentage"] = round(cat["total"] / grand_total * 100, 1) if grand_total > 0 else 0

    return {
        "categories": categories,
        "grand_total": grand_total,
        "type": type,
    }


# ===================== 5. 导出 =====================

@router.get("/export")
async def export_report(
    report_type: str = Query("income-expense", description="income-expense/balance-sheet/cash-flow/category-detail"),
    start: str | None = None,
    end: str | None = None,
    year: int | None = None,
    month: int | None = None,
    format: str = Query("csv", description="csv/excel"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """导出报表"""
    # 获取报表数据
    if report_type == "income-expense":
        data = await income_expense_report(start, end, year, "month", current_user, db)
        return _export_csv(data["periods"], ["period", "expense", "income", "net", "count"],
                          ["期间", "支出", "收入", "净收支", "笔数"], f"收支报表")
    elif report_type == "cash-flow":
        data = await cash_flow_report(start, end, year, current_user, db)
        return _export_csv(data["months"], ["month", "inflow", "outflow", "net_flow"],
                          ["月份", "流入", "流出", "净现金流"], f"现金流报表")
    elif report_type == "category-detail":
        data = await category_detail_report(start, end, year, month, "expense", current_user, db)
        rows = []
        for cat in data["categories"]:
            rows.append({
                "category_name": cat["category_name"],
                "total": cat["total"],
                "count": cat["count"],
                "percentage": f"{cat['percentage']}%",
            })
        return _export_csv(rows, ["category_name", "total", "count", "percentage"],
                          ["分类", "金额", "笔数", "占比"], f"分类明细报表")
    else:
        return {"error": "不支持的报表类型"}


def _export_csv(rows: list[dict], fields: list[str], headers: list[str], filename: str):
    """导出CSV"""
    import csv
    import io

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(headers)
    for row in rows:
        writer.writerow([row.get(f, "") for f in fields])

    content = output.getvalue().encode("utf-8-sig")  # BOM for Excel compatibility
    return StreamingResponse(
        BytesIO(content),
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename={filename}.csv"},
    )
