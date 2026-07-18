import structlog
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.database import get_db
from app.models.transaction import Transaction
from app.models.user import User

logger = structlog.get_logger()
router = APIRouter(tags=["外币结算"])

# 结算信息存储在raw_data的settlement字段中


@router.get("/api/settlements")
async def list_settlements(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """查询待结算的外币交易"""
    result = await db.execute(
        select(Transaction).where(
            Transaction.family_id == current_user.family_id,
            Transaction.is_deleted == False,
            Transaction.original_currency.isnot(None),
            Transaction.original_currency != "CNY",
        ).order_by(Transaction.transaction_time.desc())
    )
    txns = result.scalars().all()

    settlements = []
    for txn in txns:
        settlement = (txn.raw_data or {}).get("settlement", {})
        settlements.append({
            "transaction_id": txn.id,
            "transaction_time": txn.transaction_time.isoformat() if txn.transaction_time else None,
            "amount": txn.amount,
            "currency": txn.currency,
            "original_amount": txn.original_amount,
            "original_currency": txn.original_currency,
            "exchange_rate": txn.exchange_rate,
            "settlement_amount": settlement.get("settlement_amount"),
            "settlement_rate": settlement.get("settlement_rate"),
            "settlement_date": settlement.get("settlement_date"),
            "status": settlement.get("status", "pending"),
            "merchant_name": txn.merchant_name,
        })

    return settlements


@router.post("/api/transactions/{txn_id}/settlement")
async def create_settlement(
    txn_id: int,
    body: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """记录外币结算信息"""
    result = await db.execute(
        select(Transaction).where(
            Transaction.id == txn_id,
            Transaction.family_id == current_user.family_id,
        )
    )
    txn = result.scalar_one_or_none()
    if not txn:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="交易不存在")
    if not txn.original_currency or txn.original_currency == "CNY":
        raise HTTPException(status_code=400, detail="该交易不是外币交易")

    settlement_amount = body.get("settlement_amount")
    settlement_rate = body.get("settlement_rate")
    settlement_date = body.get("settlement_date")

    if not settlement_amount or not settlement_rate:
        raise HTTPException(status_code=400, detail="请提供结算金额和汇率")

    if not txn.raw_data:
        txn.raw_data = {}

    txn.raw_data["settlement"] = {
        "settlement_amount": settlement_amount,
        "settlement_rate": settlement_rate,
        "settlement_date": settlement_date,
        "status": "settled",
    }

    # 更新交易的实际人民币金额
    txn.amount = settlement_amount
    txn.exchange_rate = settlement_rate

    await db.commit()
    logger.info("settlement_created", txn_id=txn_id, amount=settlement_amount)
    return {
        "transaction_id": txn_id,
        "settlement_amount": settlement_amount,
        "settlement_rate": settlement_rate,
        "status": "settled",
    }


@router.put("/api/settlements/{txn_id}/status")
async def update_settlement_status(
    txn_id: int,
    body: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """更新结算状态"""
    result = await db.execute(
        select(Transaction).where(
            Transaction.id == txn_id,
            Transaction.family_id == current_user.family_id,
        )
    )
    txn = result.scalar_one_or_none()
    if not txn:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="交易不存在")

    settlement = (txn.raw_data or {}).get("settlement")
    if not settlement:
        raise HTTPException(status_code=404, detail="该交易没有结算信息")

    new_status = body.get("status")
    if new_status not in ["pending", "settled"]:
        raise HTTPException(status_code=400, detail="无效的状态")

    txn.raw_data["settlement"]["status"] = new_status
    await db.commit()
    return {"transaction_id": txn_id, "status": new_status}
