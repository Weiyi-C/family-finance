import structlog
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.database import get_db
from app.models.user import AccountBook, User
from app.schemas.book import BookCreate, BookResponse, BookUpdate

logger = structlog.get_logger()
router = APIRouter(prefix="/api/books", tags=["账本"])


@router.get("", response_model=list[BookResponse])
async def list_books(
    include_archived: bool = False,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(AccountBook).where(AccountBook.family_id == current_user.family_id)
    if not include_archived:
        stmt = stmt.where(AccountBook.is_archived == False)
    stmt = stmt.order_by(AccountBook.is_default.desc(), AccountBook.id)
    result = await db.execute(stmt)
    return [BookResponse.model_validate(b) for b in result.scalars()]


@router.post("", response_model=BookResponse, status_code=status.HTTP_201_CREATED)
async def create_book(
    body: BookCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    book = AccountBook(
        family_id=current_user.family_id,
        name=body.name,
        icon=body.icon,
        color=body.color,
        description=body.description,
        created_by=current_user.id,
    )
    db.add(book)
    await db.commit()
    await db.refresh(book)

    logger.info("book_created", book_id=book.id, user_id=current_user.id)
    return BookResponse.model_validate(book)


@router.get("/{book_id}", response_model=BookResponse)
async def get_book(
    book_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(AccountBook).where(
            AccountBook.id == book_id,
            AccountBook.family_id == current_user.family_id,
        )
    )
    book = result.scalar_one_or_none()
    if not book:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="账本不存在")
    return BookResponse.model_validate(book)


@router.put("/{book_id}", response_model=BookResponse)
async def update_book(
    book_id: int,
    body: BookUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(AccountBook).where(
            AccountBook.id == book_id,
            AccountBook.family_id == current_user.family_id,
        )
    )
    book = result.scalar_one_or_none()
    if not book:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="账本不存在")

    update_data = body.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(book, field, value)

    await db.commit()
    await db.refresh(book)
    return BookResponse.model_validate(book)


@router.delete("/{book_id}", response_model=BookResponse)
async def archive_book(
    book_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(AccountBook).where(
            AccountBook.id == book_id,
            AccountBook.family_id == current_user.family_id,
        )
    )
    book = result.scalar_one_or_none()
    if not book:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="账本不存在")

    if book.is_default:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="默认账本不能归档")

    book.is_archived = True
    await db.commit()
    await db.refresh(book)

    logger.info("book_archived", book_id=book.id, user_id=current_user.id)
    return BookResponse.model_validate(book)
