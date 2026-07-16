import structlog
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.database import get_db
from app.models.tag import Tag
from app.models.transaction_tag import TransactionTag
from app.models.user import User
from app.schemas.tag import TagCreate, TagResponse, TagUpdate

logger = structlog.get_logger()
router = APIRouter(prefix="/api/tags", tags=["标签"])


@router.get("", response_model=list[TagResponse])
async def list_tags(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Tag)
        .where(Tag.family_id == current_user.family_id)
        .order_by(Tag.name)
    )
    return [TagResponse.model_validate(t) for t in result.scalars()]


@router.post("", response_model=TagResponse, status_code=status.HTTP_201_CREATED)
async def create_tag(
    body: TagCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    existing = await db.execute(
        select(Tag).where(
            Tag.family_id == current_user.family_id,
            Tag.name == body.name,
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="标签名已存在")

    tag = Tag(
        family_id=current_user.family_id,
        name=body.name,
        color=body.color,
    )
    db.add(tag)
    await db.commit()
    await db.refresh(tag)

    logger.info("tag_created", tag_id=tag.id, user_id=current_user.id)
    return TagResponse.model_validate(tag)


@router.put("/{tag_id}", response_model=TagResponse)
async def update_tag(
    tag_id: int,
    body: TagUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Tag).where(Tag.id == tag_id, Tag.family_id == current_user.family_id)
    )
    tag = result.scalar_one_or_none()
    if not tag:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="标签不存在")

    if body.name and body.name != tag.name:
        dup = await db.execute(
            select(Tag).where(
                Tag.family_id == current_user.family_id,
                Tag.name == body.name,
                Tag.id != tag_id,
            )
        )
        if dup.scalar_one_or_none():
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="标签名已存在")

    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(tag, field, value)

    await db.commit()
    await db.refresh(tag)
    return TagResponse.model_validate(tag)


@router.delete("/{tag_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_tag(
    tag_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Tag).where(Tag.id == tag_id, Tag.family_id == current_user.family_id)
    )
    tag = result.scalar_one_or_none()
    if not tag:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="标签不存在")

    usage = await db.execute(
        select(func.count()).select_from(TransactionTag).where(TransactionTag.tag_id == tag_id)
    )
    if usage.scalar() > 0:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="标签已被交易使用，无法删除")

    await db.delete(tag)
    await db.commit()

    logger.info("tag_deleted", tag_id=tag_id, user_id=current_user.id)
