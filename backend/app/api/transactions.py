import structlog
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import and_, func, select, text, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.database import get_db
from app.models.transaction import Transaction
from app.models.transaction_tag import TransactionTag
from app.models.user import User
from app.schemas.transaction import (
    TransactionCreate,
    TransactionListParams,
    TransactionResponse,
    TransactionUpdate,
)

logger = structlog.get_logger()
router = APIRouter(prefix="/api/transactions", tags=["记账"])


def _to_response(txn: Transaction, tag_ids: list[int] = []) -> TransactionResponse:
    return TransactionResponse(
        id=txn.id,
        family_id=txn.family_id,
        book_id=txn.book_id,
        entry_id=txn.entry_id,
        type=txn.type,
        amount=txn.amount,
        currency=txn.currency,
        original_amount=txn.original_amount,
        original_currency=txn.original_currency,
        exchange_rate=float(txn.exchange_rate) if txn.exchange_rate else None,
        category_id=txn.category_id,
        sub_category_id=txn.sub_category_id,
        detail_category_id=txn.detail_category_id,
        payment_account_id=txn.payment_account_id,
        payment_channel_id=txn.payment_channel_id,
        platform_id=txn.platform_id,
        merchant_name=txn.merchant_name,
        description=txn.description,
        transaction_time=txn.transaction_time,
        recorded_by=txn.recorded_by,
        paid_by=txn.paid_by,
        is_quick_entry=txn.is_quick_entry,
        completion_status=txn.completion_status,
        version=txn.version,
        tag_ids=tag_ids,
    )


async def _get_tag_ids(db: AsyncSession, entry_id: str | None) -> list[int]:
    if not entry_id:
        return []
    result = await db.execute(
        select(TransactionTag.tag_id).where(TransactionTag.transaction_id == entry_id)
    )
    return [row[0] for row in result.all()]


async def _get_user_txn(db: AsyncSession, txn_id: int, family_id: int) -> Transaction | None:
    result = await db.execute(
        select(Transaction).where(
            Transaction.id == txn_id,
            Transaction.family_id == family_id,
            Transaction.entry_side == "debit",
            Transaction.is_deleted == False,
        )
    )
    return result.scalar_one_or_none()


@router.post("", response_model=TransactionResponse, status_code=status.HTTP_201_CREATED)
async def create_transaction(
    body: TransactionCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(text("SELECT nextval('entry_id_seq')"))
    entry_id = result.scalar()

    debit = Transaction(
        family_id=current_user.family_id,
        book_id=body.book_id,
        entry_id=entry_id,
        entry_side="debit",
        type=body.type,
        amount=body.amount,
        currency=body.currency,
        category_id=body.category_id,
        sub_category_id=body.sub_category_id,
        detail_category_id=body.detail_category_id,
        payment_account_id=body.payment_account_id,
        payment_channel_id=body.payment_channel_id,
        platform_id=body.platform_id,
        merchant_name=body.merchant_name,
        description=body.description,
        transaction_time=body.transaction_time,
        recorded_by=current_user.id,
        paid_by=body.paid_by or current_user.id,
        is_quick_entry=body.is_quick_entry,
        completion_status=body.completion_status,
    )
    credit = Transaction(
        family_id=current_user.family_id,
        book_id=body.book_id,
        entry_id=entry_id,
        entry_side="credit",
        type=body.type,
        amount=body.amount,
        currency=body.currency,
        payment_account_id=body.payment_account_id,
        transaction_time=body.transaction_time,
        recorded_by=current_user.id,
    )
    db.add(debit)
    db.add(credit)
    await db.flush()

    for tag_id in body.tag_ids:
        db.add(TransactionTag(transaction_id=entry_id, tag_id=tag_id))
    await db.commit()
    await db.refresh(debit)

    logger.info("transaction_created", entry_id=entry_id, type=body.type, amount=body.amount)
    return _to_response(debit, body.tag_ids)


@router.get("")
async def list_transactions(
    book_id: int | None = None,
    type: str | None = None,
    category_id: int | None = None,
    payment_account_id: int | None = None,
    merchant_name: str | None = None,
    keyword: str | None = None,
    start_date: str | None = None,
    end_date: str | None = None,
    min_amount: int | None = None,
    max_amount: int | None = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    conditions = [
        Transaction.family_id == current_user.family_id,
        Transaction.entry_side == "debit",
        Transaction.is_deleted == False,
    ]
    if book_id:
        conditions.append(Transaction.book_id == book_id)
    if type:
        conditions.append(Transaction.type == type)
    if category_id:
        conditions.append(Transaction.category_id == category_id)
    if payment_account_id:
        conditions.append(Transaction.payment_account_id == payment_account_id)
    if merchant_name:
        conditions.append(Transaction.merchant_name.ilike(f"%{merchant_name}%"))
    if keyword:
        conditions.append(Transaction.description.ilike(f"%{keyword}%"))
    if start_date:
        # Convert string date to datetime for comparison
        try:
            start_dt = datetime.strptime(start_date, "%Y-%m-%d")
            conditions.append(Transaction.transaction_time >= start_dt)
        except ValueError:
            pass
    if end_date:
        # Convert string date to datetime (end of day) for comparison
        try:
            end_dt = datetime.strptime(end_date, "%Y-%m-%d").replace(hour=23, minute=59, second=59)
            conditions.append(Transaction.transaction_time <= end_dt)
        except ValueError:
            pass
    if min_amount:
        conditions.append(Transaction.amount >= min_amount)
    if max_amount:
        conditions.append(Transaction.amount <= max_amount)

    stmt = (
        select(Transaction)
        .where(and_(*conditions))
        .order_by(Transaction.transaction_time.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    result = await db.execute(stmt)
    txns = list(result.scalars())

    # 获取总数
    count_stmt = select(func.count()).select_from(Transaction).where(and_(*conditions))
    total_result = await db.execute(count_stmt)
    total = total_result.scalar() or 0

    responses = []
    for txn in txns:
        tag_ids = await _get_tag_ids(db, txn.entry_id)
        responses.append(_to_response(txn, tag_ids))

    return {
        "items": responses,
        "total": total,
        "page": page,
        "page_size": page_size,
        "pages": (total + page_size - 1) // page_size,
    }


@router.get("/{txn_id}", response_model=TransactionResponse)
async def get_transaction(
    txn_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    txn = await _get_user_txn(db, txn_id, current_user.family_id)
    if not txn:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="交易不存在")
    tag_ids = await _get_tag_ids(db, txn.entry_id)
    return _to_response(txn, tag_ids)


@router.put("/{txn_id}", response_model=TransactionResponse)
async def update_transaction(
    txn_id: int,
    body: TransactionUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    txn = await _get_user_txn(db, txn_id, current_user.family_id)
    if not txn:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="交易不存在")

    update_data = body.model_dump(exclude_unset=True)
    tag_ids = update_data.pop("tag_ids", None)

    for field, value in update_data.items():
        setattr(txn, field, value)
    txn.version += 1

    if tag_ids is not None and txn.entry_id:
        await db.execute(
            TransactionTag.__table__.delete().where(TransactionTag.transaction_id == txn.entry_id)
        )
        for tag_id in tag_ids:
            db.add(TransactionTag(transaction_id=txn.entry_id, tag_id=tag_id))

    await db.commit()
    await db.refresh(txn)

    logger.info("transaction_updated", txn_id=txn_id, version=txn.version)
    return _to_response(txn, tag_ids or [])


@router.delete("/{txn_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_transaction(
    txn_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    txn = await _get_user_txn(db, txn_id, current_user.family_id)
    if not txn:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="交易不存在")

    if txn.entry_id:
        await db.execute(
            update(Transaction)
            .where(Transaction.entry_id == txn.entry_id, Transaction.is_deleted == False)
            .values(is_deleted=True)
        )
    else:
        txn.is_deleted = True
    await db.commit()

    logger.info("transaction_deleted", txn_id=txn_id)
