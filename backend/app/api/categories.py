import structlog
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.database import get_db
from app.models.category import Category
from app.models.user import User
from app.schemas.category import (
    CategoryCreate,
    CategoryResponse,
    CategoryTreeNode,
    CategoryUpdate,
)

logger = structlog.get_logger()
router = APIRouter(prefix="/api/categories", tags=["分类"])


def _to_response(cat: Category) -> CategoryResponse:
    return CategoryResponse(
        id=cat.id,
        parent_id=cat.parent_id,
        level=cat.level,
        name=cat.name,
        icon=cat.icon,
        color=cat.color,
        type=cat.type,
        sort_order=cat.sort_order,
        is_active=cat.is_active,
        is_system=cat.family_id is None,
    )


def _build_tree(categories: list[Category]) -> list[CategoryTreeNode]:
    by_id: dict[int, CategoryTreeNode] = {}
    roots: list[CategoryTreeNode] = []

    for cat in categories:
        node = CategoryTreeNode(
            id=cat.id,
            name=cat.name,
            icon=cat.icon,
            color=cat.color,
            type=cat.type,
            sort_order=cat.sort_order,
            is_active=cat.is_active,
            is_system=cat.family_id is None,
        )
        by_id[cat.id] = node

    for cat in categories:
        node = by_id[cat.id]
        if cat.parent_id and cat.parent_id in by_id:
            by_id[cat.parent_id].children.append(node)
        else:
            roots.append(node)

    return roots


@router.get("", response_model=list[CategoryTreeNode])
async def get_category_tree(
    type: str | None = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(Category).where(
        (Category.family_id.is_(None)) | (Category.family_id == current_user.family_id),
        Category.is_active == True,
    )
    if type:
        stmt = stmt.where(Category.type == type)
    stmt = stmt.order_by(Category.type, Category.level, Category.sort_order, Category.id)

    result = await db.execute(stmt)
    categories = list(result.scalars())
    return _build_tree(categories)


@router.get("/flat", response_model=list[CategoryResponse])
async def get_categories_flat(
    type: str | None = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(Category).where(
        (Category.family_id.is_(None)) | (Category.family_id == current_user.family_id),
    )
    if type:
        stmt = stmt.where(Category.type == type)
    stmt = stmt.order_by(Category.type, Category.level, Category.sort_order, Category.id)

    result = await db.execute(stmt)
    return [_to_response(c) for c in result.scalars()]


@router.post("", response_model=CategoryResponse, status_code=status.HTTP_201_CREATED)
async def create_category(
    body: CategoryCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    level = 1
    if body.parent_id:
        parent = await db.get(Category, body.parent_id)
        if not parent:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="父分类不存在")
        if parent.level >= 3:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="最多支持三级分类")
        level = parent.level + 1

    cat = Category(
        family_id=current_user.family_id,
        parent_id=body.parent_id,
        level=level,
        name=body.name,
        icon=body.icon,
        color=body.color,
        type=body.type,
        sort_order=body.sort_order,
    )
    db.add(cat)
    await db.commit()
    await db.refresh(cat)

    logger.info("category_created", category_id=cat.id, user_id=current_user.id)
    return _to_response(cat)


@router.put("/{category_id}", response_model=CategoryResponse)
async def update_category(
    category_id: int,
    body: CategoryUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    cat = await db.get(Category, category_id)
    if not cat:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="分类不存在")
    if cat.family_id is None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="系统分类不可修改")
    if cat.family_id != current_user.family_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="分类不存在")

    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(cat, field, value)

    await db.commit()
    await db.refresh(cat)
    return _to_response(cat)


@router.delete("/{category_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_category(
    category_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    cat = await db.get(Category, category_id)
    if not cat:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="分类不存在")
    if cat.family_id is None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="系统分类不可删除")
    if cat.family_id != current_user.family_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="分类不存在")

    has_children = await db.execute(
        select(Category).where(Category.parent_id == category_id).limit(1)
    )
    if has_children.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="存在子分类，无法删除")

    cat.is_active = False
    await db.commit()

    logger.info("category_deleted", category_id=cat.id, user_id=current_user.id)
