import structlog
from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.database import get_db
from app.models.bank import Bank
from app.models.template import AccountTypeTemplate
from app.models.user import User

logger = structlog.get_logger()
router = APIRouter(tags=["参考数据"])


@router.get("/api/banks")
async def list_banks(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Bank).order_by(Bank.sort_order))
    rows = result.scalars().all()
    return [
        {"id": b.id, "name": b.name, "code": b.code, "short_name": b.short_name, "color": b.color}
        for b in rows
    ]


@router.get("/api/account-templates")
async def list_account_templates(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(AccountTypeTemplate)
        .where(AccountTypeTemplate.is_active == True)
        .order_by(AccountTypeTemplate.group_name, AccountTypeTemplate.sort_order)
    )
    rows = result.scalars().all()
    return [
        {
            "id": t.id, "type_code": t.type_code, "name": t.name, "icon": t.icon,
            "group_name": t.group_name, "is_credit": t.is_credit,
            "has_credit_limit": t.has_credit_limit, "has_billing_day": t.has_billing_day,
            "has_due_day": t.has_due_day,
        }
        for t in rows
    ]
