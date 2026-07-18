import structlog
from datetime import date
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.database import get_db
from app.models.monitoring import ExchangeRate
from app.models.user import User

logger = structlog.get_logger()
router = APIRouter(tags=["汇率管理"])


@router.get("/api/exchange-rates")
async def list_rates(
    base_currency: str = Query(None),
    target_currency: str = Query(None),
    rate_date: str = Query(None, description="汇率日期 YYYY-MM-DD"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """查询汇率"""
    stmt = select(ExchangeRate)
    if base_currency:
        stmt = stmt.where(ExchangeRate.base_currency == base_currency)
    if target_currency:
        stmt = stmt.where(ExchangeRate.target_currency == target_currency)
    if rate_date:
        stmt = stmt.where(ExchangeRate.rate_date == rate_date)

    stmt = stmt.order_by(ExchangeRate.rate_date.desc()).limit(100)
    result = await db.execute(stmt)

    return [
        {
            "id": r.id,
            "base_currency": r.base_currency,
            "target_currency": r.target_currency,
            "rate": float(r.rate),
            "rate_type": r.rate_type,
            "source": r.source,
            "rate_date": r.rate_date.isoformat(),
        }
        for r in result.scalars()
    ]


@router.post("/api/exchange-rates", status_code=201)
async def create_rate(
    body: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """添加汇率"""
    base = body.get("base_currency")
    target = body.get("target_currency")
    rate = body.get("rate")
    rate_date = body.get("rate_date")

    if not all([base, target, rate, rate_date]):
        raise HTTPException(status_code=400, detail="缺少必填字段")

    exchange_rate = ExchangeRate(
        base_currency=base,
        target_currency=target,
        rate=rate,
        rate_type=body.get("rate_type", "spot"),
        source=body.get("source", "manual"),
        rate_date=date.fromisoformat(rate_date),
    )
    db.add(exchange_rate)
    await db.commit()
    await db.refresh(exchange_rate)

    return {
        "id": exchange_rate.id,
        "base_currency": exchange_rate.base_currency,
        "target_currency": exchange_rate.target_currency,
        "rate": float(exchange_rate.rate),
        "rate_date": exchange_rate.rate_date.isoformat(),
    }


@router.get("/api/exchange-rates/convert")
async def convert_currency(
    amount: int = Query(..., description="金额（分）"),
    from_currency: str = Query(...),
    to_currency: str = Query(...),
    rate_date: str = Query(None, description="汇率日期，默认最新"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """货币转换"""
    if from_currency == to_currency:
        return {"amount": amount, "converted": amount, "rate": 1.0}

    # 查找汇率
    stmt = select(ExchangeRate).where(
        ExchangeRate.base_currency == from_currency,
        ExchangeRate.target_currency == to_currency,
    )
    if rate_date:
        stmt = stmt.where(ExchangeRate.rate_date <= rate_date)
    stmt = stmt.order_by(ExchangeRate.rate_date.desc()).limit(1)

    result = await db.execute(stmt)
    rate_obj = result.scalar_one_or_none()
    if not rate_obj:
        raise HTTPException(status_code=404, detail="未找到汇率")

    converted = int(amount * float(rate_obj.rate))
    return {
        "amount": amount,
        "converted": converted,
        "rate": float(rate_obj.rate),
        "rate_date": rate_obj.rate_date.isoformat(),
    }
