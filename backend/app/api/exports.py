import csv
import io

import structlog
from fastapi import APIRouter, Depends, Query
from fastapi.responses import StreamingResponse
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.database import get_db
from app.models.user import User

logger = structlog.get_logger()
router = APIRouter(tags=["数据导出"])


@router.get("/api/export/transactions")
async def export_transactions(
    format: str = Query("csv", pattern="^(csv|json)$"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        text("""
            SELECT t.id, t.type, t.amount, t.currency, t.merchant_name, t.description,
                   t.transaction_time, c.name as category_name
            FROM transactions t
            LEFT JOIN categories c ON t.category_id = c.id
            WHERE t.family_id = :fid AND t.is_deleted = false
            ORDER BY t.transaction_time DESC
        """),
        {"fid": current_user.family_id},
    )
    rows = [dict(row._mapping) for row in result.fetchall()]

    for row in rows:
        for k, v in row.items():
            if hasattr(v, "isoformat"):
                row[k] = v.isoformat()

    if format == "json":
        import json
        content = json.dumps(rows, ensure_ascii=False, indent=2, default=str)
        return StreamingResponse(
            io.BytesIO(content.encode("utf-8")),
            media_type="application/json",
            headers={"Content-Disposition": "attachment; filename=transactions.json"},
        )

    output = io.StringIO()
    if rows:
        writer = csv.DictWriter(output, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)
    return StreamingResponse(
        io.BytesIO(output.getvalue().encode("utf-8-sig")),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=transactions.csv"},
    )


@router.get("/api/export/accounts")
async def export_accounts(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        text("SELECT * FROM payment_accounts WHERE family_id = :fid"),
        {"fid": current_user.family_id},
    )
    rows = [dict(row._mapping) for row in result.fetchall()]
    for row in rows:
        for k, v in row.items():
            if hasattr(v, "isoformat"):
                row[k] = v.isoformat()

    import json
    content = json.dumps(rows, ensure_ascii=False, indent=2, default=str)
    return StreamingResponse(
        io.BytesIO(content.encode("utf-8")),
        media_type="application/json",
        headers={"Content-Disposition": "attachment; filename=accounts.json"},
    )


@router.get("/api/export/categories")
async def export_categories(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        text("SELECT * FROM categories WHERE family_id = :fid OR family_id IS NULL ORDER BY id"),
        {"fid": current_user.family_id},
    )
    rows = [dict(row._mapping) for row in result.fetchall()]
    for row in rows:
        for k, v in row.items():
            if hasattr(v, "isoformat"):
                row[k] = v.isoformat()

    import json
    content = json.dumps(rows, ensure_ascii=False, indent=2, default=str)
    return StreamingResponse(
        io.BytesIO(content.encode("utf-8")),
        media_type="application/json",
        headers={"Content-Disposition": "attachment; filename=categories.json"},
    )
