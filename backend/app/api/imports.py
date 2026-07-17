import structlog
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.database import get_db
from app.models.bill_import import BillImport, BillImportItem
from app.models.user import User
from app.schemas.extra import ImportCreate, ImportResponse, ImportItemResponse

logger = structlog.get_logger()
router = APIRouter(tags=["账单导入"])


@router.get("/api/imports", response_model=list[ImportResponse])
async def list_imports(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(BillImport)
        .where(BillImport.family_id == current_user.family_id)
        .order_by(BillImport.created_at.desc())
    )
    return [ImportResponse.model_validate(i) for i in result.scalars()]


@router.post("/api/imports", response_model=ImportResponse, status_code=201)
async def create_import(
    body: ImportCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    imp = BillImport(
        family_id=current_user.family_id,
        book_id=body.book_id,
        source=body.source,
        file_format=body.file_format,
        total_rows=len(body.items),
        imported_by=current_user.id,
        status="pending",
    )
    db.add(imp)
    await db.flush()

    for item_data in body.items:
        item = BillImportItem(
            import_id=imp.id,
            raw_data=item_data,
            parsed_amount=item_data.get("amount"),
            parsed_merchant=item_data.get("merchant"),
        )
        db.add(item)

    await db.commit()
    await db.refresh(imp)
    return ImportResponse.model_validate(imp)


@router.get("/api/imports/{import_id}", response_model=ImportResponse)
async def get_import(
    import_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(BillImport).where(
            BillImport.id == import_id,
            BillImport.family_id == current_user.family_id,
        )
    )
    imp = result.scalar_one_or_none()
    if not imp:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="导入记录不存在")
    return ImportResponse.model_validate(imp)


@router.get("/api/imports/{import_id}/items", response_model=list[ImportItemResponse])
async def list_import_items(
    import_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(BillImportItem).where(BillImportItem.import_id == import_id)
    )
    return [ImportItemResponse.model_validate(i) for i in result.scalars()]


@router.delete("/api/imports/{import_id}", status_code=204)
async def delete_import(
    import_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(BillImport).where(
            BillImport.id == import_id,
            BillImport.family_id == current_user.family_id,
        )
    )
    imp = result.scalar_one_or_none()
    if not imp:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="导入记录不存在")
    await db.delete(imp)
    await db.commit()
