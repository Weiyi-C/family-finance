import structlog
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.database import get_db
from app.models.merchant_alias import MerchantAlias
from app.models.user import User
from app.schemas.extra import AliasCreate, AliasUpdate, AliasResponse

logger = structlog.get_logger()
router = APIRouter(tags=["商户别名"])


@router.get("/api/aliases", response_model=list[AliasResponse])
async def list_aliases(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(MerchantAlias)
        .where(MerchantAlias.family_id == current_user.family_id)
        .order_by(MerchantAlias.hit_count.desc())
    )
    return [AliasResponse.model_validate(a) for a in result.scalars()]


@router.post("/api/aliases", response_model=AliasResponse, status_code=201)
async def create_alias(
    body: AliasCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    alias = MerchantAlias(family_id=current_user.family_id, **body.model_dump())
    db.add(alias)
    await db.commit()
    await db.refresh(alias)
    return AliasResponse.model_validate(alias)


@router.put("/api/aliases/{alias_id}", response_model=AliasResponse)
async def update_alias(
    alias_id: int,
    body: AliasUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(MerchantAlias).where(
            MerchantAlias.id == alias_id,
            MerchantAlias.family_id == current_user.family_id,
        )
    )
    alias = result.scalar_one_or_none()
    if not alias:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="别名不存在")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(alias, field, value)
    await db.commit()
    await db.refresh(alias)
    return AliasResponse.model_validate(alias)


@router.delete("/api/aliases/{alias_id}", status_code=204)
async def delete_alias(
    alias_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(MerchantAlias).where(
            MerchantAlias.id == alias_id,
            MerchantAlias.family_id == current_user.family_id,
        )
    )
    alias = result.scalar_one_or_none()
    if not alias:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="别名不存在")
    await db.delete(alias)
    await db.commit()
