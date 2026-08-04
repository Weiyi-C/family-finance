"""AI 辅助账单导入 API"""

import base64
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.database import get_db
from app.models.user import User, Family
from app.parsers import detect_and_decode
from app.services.ai_service import get_ai_service


async def _get_ai_service(current_user: User, db: AsyncSession):
    """获取 AI 服务实例（从家庭设置读取）"""
    from sqlalchemy import select

    result = await db.execute(select(Family).where(Family.id == current_user.family_id))
    family = result.scalar_one_or_none()

    family_settings = family.settings if family else {}
    user_settings = current_user.settings or {}

    return get_ai_service(family_settings=family_settings, user_settings=user_settings)

router = APIRouter(tags=["AI导入"])


@router.post("/api/ai/parse-file")
async def ai_parse_file(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """使用 AI 解析账单文件

    支持任意文本格式的账单文件，AI 会自动识别格式并提取交易记录
    """
    ai_service = await _get_ai_service(current_user, db)
    if not ai_service:
        raise HTTPException(status_code=400, detail="请先在设置中配置 AI 功能")

    # 读取文件内容
    content_bytes = await file.read()
    filename = file.filename or ""
    ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""

    # 对于文本文件，直接读取内容
    if ext in ("csv", "txt", "tsv"):
        content_str = detect_and_decode(content_bytes)
        transactions = await ai_service.parse_bill_file(content_str, ext)
    else:
        raise HTTPException(status_code=400, detail=f"AI 暂不支持 {ext} 格式的文件解析，请使用 CSV 或 TXT 格式")

    if not transactions:
        raise HTTPException(status_code=500, detail="AI 未能解析出交易记录，请检查文件内容或 AI 配置")

    return {
        "transactions": transactions,
        "count": len(transactions),
        "source": "ai",
    }


@router.post("/api/ai/parse-image")
async def ai_parse_image(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """使用 AI 从图片中识别账单

    支持拍照或截图的账单图片，AI 会识别图片中的交易记录
    """
    ai_service = await _get_ai_service(current_user, db)
    if not ai_service:
        raise HTTPException(status_code=400, detail="请先在设置中配置 AI 功能")

    # 检查文件类型
    content_type = file.content_type or ""
    if not content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="请上传图片文件（支持 JPG、PNG 等格式）")

    # 读取图片并转为 base64
    image_bytes = await file.read()
    image_base64 = base64.b64encode(image_bytes).decode("utf-8")

    # 调用 AI 识别
    transactions = await ai_service.parse_bill_image(image_base64)

    if not transactions:
        raise HTTPException(status_code=500, detail="AI 未能识别出交易记录，请确保图片清晰且包含账单信息")

    return {
        "transactions": transactions,
        "count": len(transactions),
        "source": "ai_vision",
    }


@router.post("/api/ai/categorize-batch")
async def ai_categorize_batch(
    body: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """批量使用 AI 对交易进行分类"""
    ai_service = await _get_ai_service(current_user, db)
    if not ai_service:
        raise HTTPException(status_code=400, detail="请先在设置中配置 AI 功能")

    from app.models.category import Category
    from sqlalchemy import select

    # 获取分类列表
    cats_result = await db.execute(
        select(Category).where(
            (Category.family_id == current_user.family_id) | (Category.family_id.is_(None))
        )
    )
    categories = [
        {"id": c.id, "name": c.name, "level": c.level}
        for c in cats_result.scalars()
    ]

    transactions = body.get("transactions", [])
    results = []

    for txn in transactions[:50]:  # 限制批量大小
        result = await ai_service.categorize_transaction(
            merchant=txn.get("merchant", ""),
            description=txn.get("description", ""),
            amount=txn.get("amount", 0),
            txn_type=txn.get("type", "expense"),
            categories=categories,
        )
        results.append({
            "merchant": txn.get("merchant", ""),
            "ai_category": result.get("category_name") if result else None,
            "ai_confidence": result.get("confidence") if result else None,
            "ai_reason": result.get("reason") if result else None,
        })

    return {
        "results": results,
        "count": len(results),
    }
