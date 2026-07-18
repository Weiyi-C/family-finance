import os
import uuid

import structlog
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.core.deps import get_current_user
from app.database import get_db
from app.models.transaction import Transaction
from app.models.user import User

logger = structlog.get_logger()
router = APIRouter(tags=["附件管理"])

# 附件存储在raw_data的attachments字段中


@router.get("/api/transactions/{txn_id}/attachments")
async def list_attachments(
    txn_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """获取交易的附件列表"""
    result = await db.execute(
        select(Transaction).where(
            Transaction.id == txn_id,
            Transaction.family_id == current_user.family_id,
        )
    )
    txn = result.scalar_one_or_none()
    if not txn:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="交易不存在")

    attachments = (txn.raw_data or {}).get("attachments", [])
    return attachments


@router.post("/api/transactions/{txn_id}/attachments")
async def upload_attachment(
    txn_id: int,
    file: UploadFile = File(...),
    description: str = Form(""),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """上传附件到交易"""
    result = await db.execute(
        select(Transaction).where(
            Transaction.id == txn_id,
            Transaction.family_id == current_user.family_id,
        )
    )
    txn = result.scalar_one_or_none()
    if not txn:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="交易不存在")

    # 保存文件
    upload_dir = os.path.join(settings.UPLOAD_DIR, str(current_user.family_id))
    os.makedirs(upload_dir, exist_ok=True)

    ext = os.path.splitext(file.filename or "")[1]
    filename = f"{uuid.uuid4().hex}{ext}"
    filepath = os.path.join(upload_dir, filename)

    content = await file.read()
    with open(filepath, "wb") as f:
        f.write(content)

    # 添加到交易的raw_data
    if not txn.raw_data:
        txn.raw_data = {}
    if "attachments" not in txn.raw_data:
        txn.raw_data["attachments"] = []

    attachment = {
        "id": uuid.uuid4().hex[:16],
        "filename": file.filename,
        "stored_path": filepath,
        "size": len(content),
        "content_type": file.content_type,
        "description": description,
        "uploaded_by": current_user.id,
    }
    txn.raw_data["attachments"].append(attachment)

    await db.commit()
    logger.info("attachment_uploaded", txn_id=txn_id, filename=file.filename)
    return attachment


@router.delete("/api/transactions/{txn_id}/attachments/{attachment_id}")
async def delete_attachment(
    txn_id: int,
    attachment_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """删除附件"""
    result = await db.execute(
        select(Transaction).where(
            Transaction.id == txn_id,
            Transaction.family_id == current_user.family_id,
        )
    )
    txn = result.scalar_one_or_none()
    if not txn:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="交易不存在")

    attachments = (txn.raw_data or {}).get("attachments", [])
    target = next((a for a in attachments if a["id"] == attachment_id), None)
    if not target:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="附件不存在")

    # 删除文件
    if os.path.exists(target.get("stored_path", "")):
        os.remove(target["stored_path"])

    txn.raw_data["attachments"] = [a for a in attachments if a["id"] != attachment_id]
    await db.commit()
    return {"message": "已删除"}
