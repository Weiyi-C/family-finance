import structlog
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.database import get_db
from app.models.transaction import Transaction
from app.models.user import User

logger = structlog.get_logger()
router = APIRouter(tags=["退款追踪"])


class TransactionRefund:
    """退款追踪模型（使用JSONB存储在raw_data中）"""
    pass


@router.get("/api/refunds")
async def list_refunds(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """查询退款记录（从transactions的raw_data中提取）"""
    result = await db.execute(
        select(Transaction).where(
            Transaction.family_id == current_user.family_id,
            Transaction.type == "expense",
            Transaction.is_deleted == False,
            Transaction.raw_data.has_key("refund_of"),
        ).order_by(Transaction.transaction_time.desc())
    )
    txns = result.scalars().all()

    refunds = []
    for txn in txns:
        refund_info = txn.raw_data.get("refund_of", {})
        refunds.append({
            "id": txn.id,
            "original_txn_id": refund_info.get("original_txn_id"),
            "amount": txn.amount,
            "status": refund_info.get("status", "pending"),
            "refund_time": txn.transaction_time.isoformat() if txn.transaction_time else None,
            "reason": refund_info.get("reason"),
            "platform_refund_id": refund_info.get("platform_refund_id"),
            "description": txn.description,
        })

    return refunds


@router.post("/api/transactions/{txn_id}/refund")
async def create_refund(
    txn_id: int,
    body: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """为交易创建退款记录"""
    # 查找原始交易
    result = await db.execute(
        select(Transaction).where(
            Transaction.id == txn_id,
            Transaction.family_id == current_user.family_id,
            Transaction.is_deleted == False,
        )
    )
    original = result.scalar_one_or_none()
    if not original:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="原始交易不存在")

    # 创建退款交易
    refund_amount = body.get("amount", original.amount)
    if refund_amount > original.amount:
        raise HTTPException(status_code=400, detail="退款金额不能超过原始金额")

    refund_txn = Transaction(
        family_id=current_user.family_id,
        book_id=original.book_id,
        entry_side="credit",
        type="income",
        amount=refund_amount,
        currency=original.currency,
        category_id=original.category_id,
        sub_category_id=original.sub_category_id,
        payment_account_id=original.payment_account_id,
        payment_channel_id=original.payment_channel_id,
        platform_id=original.platform_id,
        merchant_name=original.merchant_name,
        description=f"退款: {original.description or ''}",
        transaction_time=body.get("refund_time", datetime.now()),
        recorded_by=current_user.id,
        paid_by=current_user.id,
        completion_status="complete",
        raw_data={
            "refund_of": {
                "original_txn_id": txn_id,
                "amount": refund_amount,
                "status": body.get("status", "received"),
                "reason": body.get("reason"),
                "platform_refund_id": body.get("platform_refund_id"),
            }
        },
    )
    db.add(refund_txn)
    await db.commit()
    await db.refresh(refund_txn)

    logger.info("refund_created", original_id=txn_id, refund_id=refund_txn.id, amount=refund_amount)
    return {
        "id": refund_txn.id,
        "original_txn_id": txn_id,
        "amount": refund_txn.amount,
        "status": "received",
    }


@router.put("/api/refunds/{refund_id}/status")
async def update_refund_status(
    refund_id: int,
    body: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """更新退款状态"""
    result = await db.execute(
        select(Transaction).where(
            Transaction.id == refund_id,
            Transaction.family_id == current_user.family_id,
        )
    )
    refund = result.scalar_one_or_none()
    if not refund or not refund.raw_data or "refund_of" not in refund.raw_data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="退款记录不存在")

    new_status = body.get("status")
    if new_status not in ["pending", "approved", "received"]:
        raise HTTPException(status_code=400, detail="无效的状态")

    refund.raw_data["refund_of"]["status"] = new_status
    await db.commit()
    return {"id": refund_id, "status": new_status}
