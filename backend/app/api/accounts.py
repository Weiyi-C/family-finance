import structlog
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.database import get_db
from app.models.account import PaymentAccount
from app.models.user import User
from app.schemas.account import (
    AccountBalance,
    AccountCreate,
    AccountResponse,
    AccountUpdate,
)

logger = structlog.get_logger()
router = APIRouter(prefix="/api/accounts", tags=["资金来源"])


@router.get("", response_model=list[AccountResponse])
async def list_accounts(
    include_hidden: bool = False,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(PaymentAccount).where(
        PaymentAccount.family_id == current_user.family_id,
        PaymentAccount.is_active == True,
    )
    if not include_hidden:
        stmt = stmt.where(PaymentAccount.is_hidden == False)
    stmt = stmt.order_by(PaymentAccount.sort_order, PaymentAccount.id)
    result = await db.execute(stmt)
    return [AccountResponse.model_validate(a) for a in result.scalars()]


@router.post("", response_model=AccountResponse, status_code=status.HTTP_201_CREATED)
async def create_account(
    body: AccountCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    account = PaymentAccount(
        family_id=current_user.family_id,
        user_id=current_user.id,
        template_id=body.template_id,
        name=body.name,
        type_code=body.type_code,
        icon=body.icon,
        color=body.color,
        bank_name=body.bank_name,
        bank_code=body.bank_code,
        card_tail=body.card_tail,
        card_type=body.card_type,
        initial_balance=body.initial_balance,
        credit_limit=body.credit_limit,
        billing_day=body.billing_day,
        due_day=body.due_day,
        grace_days=body.grace_days,
        is_shared=body.is_shared,
        shared_with=body.shared_with,
        share_type=body.share_type,
        group_name=body.group_name,
    )
    db.add(account)
    await db.commit()
    await db.refresh(account)

    logger.info("account_created", account_id=account.id, user_id=current_user.id)
    return AccountResponse.model_validate(account)


@router.get("/{account_id}", response_model=AccountResponse)
async def get_account(
    account_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(PaymentAccount).where(
            PaymentAccount.id == account_id,
            PaymentAccount.family_id == current_user.family_id,
        )
    )
    account = result.scalar_one_or_none()
    if not account:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="账户不存在")
    return AccountResponse.model_validate(account)


@router.put("/{account_id}", response_model=AccountResponse)
async def update_account(
    account_id: int,
    body: AccountUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(PaymentAccount).where(
            PaymentAccount.id == account_id,
            PaymentAccount.family_id == current_user.family_id,
        )
    )
    account = result.scalar_one_or_none()
    if not account:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="账户不存在")

    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(account, field, value)

    await db.commit()
    await db.refresh(account)
    return AccountResponse.model_validate(account)


@router.delete("/{account_id}", response_model=AccountResponse)
async def archive_account(
    account_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(PaymentAccount).where(
            PaymentAccount.id == account_id,
            PaymentAccount.family_id == current_user.family_id,
        )
    )
    account = result.scalar_one_or_none()
    if not account:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="账户不存在")

    account.is_active = False
    await db.commit()
    await db.refresh(account)

    logger.info("account_archived", account_id=account.id, user_id=current_user.id)
    return AccountResponse.model_validate(account)


@router.get("/{account_id}/balance", response_model=AccountBalance)
async def get_account_balance(
    account_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(PaymentAccount).where(
            PaymentAccount.id == account_id,
            PaymentAccount.family_id == current_user.family_id,
        )
    )
    account = result.scalar_one_or_none()
    if not account:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="账户不存在")

    is_credit = account.credit_limit is not None

    if is_credit:
        # 信用卡：额度 - 已用
        balance = account.credit_limit - account.used_amount
    else:
        # 非信用卡：初始余额 + 收入 - 支出
        from sqlalchemy import func, case
        from app.models.transaction import Transaction

        # 计算该账户的交易净额
        income_sum = func.coalesce(
            func.sum(
                case(
                    (Transaction.type == "income", Transaction.amount),
                    else_=0,
                )
            ),
            0,
        )
        expense_sum = func.coalesce(
            func.sum(
                case(
                    (Transaction.type == "expense", Transaction.amount),
                    else_=0,
                )
            ),
            0,
        )

        txn_result = await db.execute(
            select(
                (income_sum - expense_sum).label("net")
            ).where(
                Transaction.payment_account_id == account_id,
                Transaction.family_id == current_user.family_id,
                Transaction.is_deleted == False,
                Transaction.entry_side == "debit",
            )
        )
        txn_sum = txn_result.scalar() or 0
        balance = account.initial_balance + txn_sum

    return AccountBalance(
        id=account.id,
        name=account.name,
        type_code=account.type_code,
        balance=balance,
        is_credit=is_credit,
        credit_limit=account.credit_limit,
        used_amount=account.used_amount if is_credit else None,
    )
