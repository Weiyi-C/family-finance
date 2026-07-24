"""账单导入 API 端点"""

import structlog
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.database import get_db
from app.models.bill_import import BillImport, BillImportItem
from app.models.category import Category
from app.models.channel import PaymentChannel
from app.models.transaction import Transaction
from app.models.user import User

# 从新模块导入
from app.parsers import detect_and_decode, parse_alipay_csv, parse_wechat_csv, parse_excel
from app.services import (
    auto_categorize,
    ai_suggest_category,
    auto_assign_tags,
    match_payment_method_to_account,
    suggest_account_type,
)

logger = structlog.get_logger()
router = APIRouter(tags=["账单导入"])


# ===================== 平台别名映射 =====================
PLATFORM_ALIASES = {
    "淘宝闪购": "淘宝", "天猫": "淘宝", "淘宝商城": "淘宝",
    "京东到家": "京东", "京东商城": "京东",
    "美团外卖": "美团", "大众点评": "美团",
    "饿了么星选": "饿了么",
    "拼多多": "拼多多", "抖音商城": "抖音",
}


@router.post("/api/imports/upload")
async def upload_import(
    file: UploadFile = File(...),
    book_id: int = Form(...),
    source: str = Form("auto"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """上传账单文件并解析"""
    content_bytes = await file.read()
    filename = file.filename or ""
    ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""

    try:
        if ext == "csv":
            content_str = detect_and_decode(content_bytes)
            if source == "auto":
                if "支付宝" in content_str[:500] or "交易号" in content_str[:1000]:
                    source = "alipay"
                elif "微信" in content_str[:500] or "交易单号" in content_str[:1000]:
                    source = "wechat"
                else:
                    source = "alipay"

            if source == "alipay":
                items, meta = parse_alipay_csv(content_str)
            elif source == "wechat":
                items, meta = parse_wechat_csv(content_str)
            else:
                raise ValueError(f"不支持的 CSV 来源: {source}")
            file_format = "csv"
        elif ext in ("xlsx", "xls"):
            items, meta = parse_excel(content_bytes)
            source = "auto"
            file_format = "xlsx"
        else:
            raise ValueError(f"不支持的文件格式: {ext}")
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"文件解析失败: {str(e)}")

    # 去重检查
    order_nos = [i.get("order_no") for i in items if i.get("order_no")]
    existing_orders = set()
    if order_nos:
        result = await db.execute(
            select(BillImportItem.raw_data).where(
                BillImportItem.import_id.in_(
                    select(BillImport.id).where(BillImport.family_id == current_user.family_id)
                )
            )
        )
        for row in result.scalars():
            if row and row.get("order_no") in order_nos:
                existing_orders.add(row["order_no"])

    new_items = [i for i in items if not i.get("order_no") or i["order_no"] not in existing_orders]
    skipped_dup = len(items) - len(new_items)

    # === 自动匹配账户 ===
    from app.models.account import PaymentAccount

    accounts_result = await db.execute(
        select(PaymentAccount).where(
            PaymentAccount.family_id == current_user.family_id,
            PaymentAccount.is_active == True,
        )
    )
    user_accounts = list(accounts_result.scalars())

    detected_methods = meta.get("detected_methods", [])
    method_matches = {}
    unmatched_methods = []
    for method in detected_methods:
        matched_id = match_payment_method_to_account(method, user_accounts)
        if matched_id:
            method_matches[method] = matched_id
        else:
            suggestion = suggest_account_type(method)
            unmatched_methods.append({"method": method, "suggestion": suggestion})

    # === 自动分类和标签（在存储之前完成） ===
    categories_result = await db.execute(
        select(Category).where(
            (Category.family_id == current_user.family_id) | (Category.family_id.is_(None)),
        )
    )
    category_names = {c.name: c.id for c in categories_result.scalars()}

    for item in new_items:
        txn_type = item.get("type", "expense")
        merchant = item.get("merchant", "")
        description = item.get("description", "")
        platform = item.get("platform", "")
        pm = item.get("payment_method", "")

        # 1. 规则分类 + 标签
        suggested_cat, auto_tags = auto_categorize(merchant, description, txn_type, platform, pm)

        # 2. AI 回退
        if not suggested_cat and (merchant or description):
            try:
                ai_result = await ai_suggest_category(db, current_user, merchant, description)
                if ai_result:
                    suggested_cat = ai_result
            except Exception:
                pass

        # 3. 写入分类建议
        if suggested_cat:
            cat_id = category_names.get(suggested_cat)
            if cat_id:
                item["suggested_category_id"] = cat_id
                item["suggested_category_name"] = suggested_cat

        # 4. 写入标签建议
        if auto_tags:
            item["suggested_tags"] = auto_tags

        # 5. 自动匹配账户
        if pm and pm in method_matches:
            item["suggested_account_id"] = method_matches[pm]

    # === 存储到数据库（此时 raw_data 已包含分类和标签） ===
    imp = BillImport(
        family_id=current_user.family_id,
        book_id=book_id,
        source=source,
        file_format=file_format,
        total_rows=len(items),
        parsed_count=len(new_items),
        imported_by=current_user.id,
        status="parsed",
    )
    db.add(imp)
    await db.flush()

    for item_data in new_items:
        item = BillImportItem(
            import_id=imp.id,
            raw_data=item_data,
            parsed_amount=item_data.get("amount"),
            parsed_merchant=item_data.get("merchant"),
            action="pending",
        )
        db.add(item)

    await db.commit()
    await db.refresh(imp)

    return {
        "id": imp.id,
        "source": source,
        "file_format": file_format,
        "total_rows": len(items),
        "parsed_count": len(new_items),
        "skipped_duplicate": skipped_dup,
        "status": "parsed",
        "meta": meta,
        "method_matches": method_matches,
        "unmatched_methods": unmatched_methods,
        "preview": new_items[:30],
    }


@router.get("/api/imports")
async def list_imports(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """列出所有导入记录"""
    result = await db.execute(
        select(BillImport)
        .where(BillImport.family_id == current_user.family_id)
        .order_by(BillImport.created_at.desc())
    )
    rows = result.scalars().all()
    return [
        {
            "id": i.id,
            "family_id": i.family_id,
            "book_id": i.book_id,
            "source": i.source,
            "file_format": i.file_format,
            "status": i.status,
            "total_rows": i.total_rows,
            "parsed_count": i.parsed_count,
            "matched_count": i.matched_count,
            "new_count": i.new_count,
            "created_at": i.created_at,
        }
        for i in rows
    ]


@router.get("/api/imports/{import_id}")
async def get_import(
    import_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """获取单条导入记录"""
    result = await db.execute(
        select(BillImport).where(
            BillImport.id == import_id,
            BillImport.family_id == current_user.family_id,
        )
    )
    imp = result.scalar_one_or_none()
    if not imp:
        raise HTTPException(status_code=404, detail="导入记录不存在")
    return imp


@router.get("/api/imports/{import_id}/items")
async def list_import_items(
    import_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """获取导入明细"""
    # 验证权限
    imp_result = await db.execute(
        select(BillImport).where(
            BillImport.id == import_id,
            BillImport.family_id == current_user.family_id,
        )
    )
    if not imp_result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="导入记录不存在")

    result = await db.execute(
        select(BillImportItem)
        .where(BillImportItem.import_id == import_id)
        .order_by(BillImportItem.id)
    )
    return [
        {
            "id": item.id,
            "import_id": item.import_id,
            "raw_data": item.raw_data,
            "parsed_amount": item.parsed_amount,
            "parsed_merchant": item.parsed_merchant,
            "action": item.action,
            "matched_txn_id": item.matched_txn_id,
        }
        for item in result.scalars()
    ]


@router.post("/api/imports/{import_id}/confirm")
async def confirm_import(
    import_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """确认导入，创建交易记录"""
    from sqlalchemy import text

    result = await db.execute(
        select(BillImport).where(
            BillImport.id == import_id,
            BillImport.family_id == current_user.family_id,
        )
    )
    imp = result.scalar_one_or_none()
    if not imp:
        raise HTTPException(status_code=404, detail="导入记录不存在")
    if imp.status == "confirmed":
        raise HTTPException(status_code=400, detail="该导入已确认")

    items_result = await db.execute(
        select(BillImportItem).where(
            BillImportItem.import_id == import_id,
            BillImportItem.action == "pending",
        )
    )
    items = items_result.scalars().all()

    # 加载分类名称→ID映射
    cats_result = await db.execute(
        select(Category).where(
            (Category.family_id == current_user.family_id) | (Category.family_id.is_(None)),
        )
    )
    _category_name_map = {c.name: c.id for c in cats_result.scalars()}

    seq_result = await db.execute(text("SELECT nextval('entry_id_seq')"))
    base_entry_id = seq_result.scalar()

    created = 0
    skipped = 0
    for item in items:
        raw = item.raw_data
        amount = item.parsed_amount or raw.get("amount", 0)

        if not amount or amount <= 0:
            skipped += 1
            item.action = "skipped"
            continue

        entry_id = base_entry_id + created

        # 解析交易时间
        txn_time_str = raw.get("transaction_time", "")
        txn_time = __import__("datetime").datetime.now()
        if isinstance(txn_time_str, str) and txn_time_str:
            for fmt in ["%Y-%m-%d %H:%M:%S", "%Y/%m/%d %H:%M", "%Y-%m-%d %H:%M", "%Y-%m-%d"]:
                try:
                    txn_time = __import__("datetime").datetime.strptime(txn_time_str.strip(), fmt)
                    break
                except ValueError:
                    continue

        # 确定账户ID
        from app.models.account import PaymentAccount

        default_account_id = None
        method_account_map = {}
        account_id = None

        suggested_account_id = raw.get("suggested_account_id")
        if suggested_account_id:
            account_id = suggested_account_id
        elif method_account_map:
            pm = raw.get("payment_method", "")
            account_id = method_account_map.get(pm)

        # 查找平台ID
        platform_name = raw.get("platform", "")
        platform_id = None
        if platform_name:
            from app.models.platform import Platform

            platform_result = await db.execute(
                select(Platform.id).where(
                    Platform.name == platform_name,
                    (Platform.family_id.is_(None)) | (Platform.family_id == current_user.family_id),
                ).limit(1)
            )
            platform_id = platform_result.scalar()
            if not platform_id:
                mapped_name = PLATFORM_ALIASES.get(platform_name)
                if mapped_name:
                    platform_result = await db.execute(
                        select(Platform.id).where(Platform.name == mapped_name).limit(1)
                    )
                    platform_id = platform_result.scalar()

        # 查找支付渠道ID
        channel_id = None
        if imp.source == "alipay":
            channel_result = await db.execute(
                select(PaymentChannel.id).where(PaymentChannel.name == "支付宝").limit(1)
            )
            channel_id = channel_result.scalar()
        elif imp.source == "wechat":
            channel_result = await db.execute(
                select(PaymentChannel.id).where(PaymentChannel.name == "微信支付").limit(1)
            )
            channel_id = channel_result.scalar()

        txn_type = raw.get("type", "expense")

        # 使用自动分类建议，否则实时分类
        category_id = raw.get("suggested_category_id")
        suggested_tags = raw.get("suggested_tags", [])

        if not category_id:
            merchant = raw.get("merchant", "")
            description = raw.get("description", "")
            platform = raw.get("platform", "")
            pm = raw.get("payment_method", "")
            cat_name, auto_tags = auto_categorize(merchant, description, txn_type, platform, pm)

            if not cat_name and (merchant or description):
                try:
                    cat_name = await ai_suggest_category(db, current_user, merchant, description)
                except Exception:
                    pass

            if cat_name:
                cat_id = _category_name_map.get(cat_name)
                if cat_id:
                    category_id = cat_id
            if auto_tags:
                suggested_tags = auto_tags

        # 双式记账
        debit = Transaction(
            family_id=current_user.family_id,
            book_id=imp.book_id,
            entry_id=entry_id,
            entry_side="debit",
            type=txn_type,
            amount=amount,
            currency="CNY",
            category_id=category_id,
            merchant_name=item.parsed_merchant or raw.get("merchant"),
            description=raw.get("description"),
            transaction_time=txn_time,
            payment_account_id=account_id,
            payment_channel_id=channel_id,
            platform_id=platform_id,
            recorded_by=current_user.id,
            paid_by=current_user.id,
            completion_status="complete",
            import_id=imp.id,
            raw_data=raw,
        )
        credit = Transaction(
            family_id=current_user.family_id,
            book_id=imp.book_id,
            entry_id=entry_id,
            entry_side="credit",
            type=txn_type,
            amount=amount,
            currency="CNY",
            payment_account_id=account_id,
            transaction_time=txn_time,
            recorded_by=current_user.id,
            import_id=imp.id,
        )
        db.add(debit)
        db.add(credit)
        await db.flush()

        # 自动打标签（使用 entry_id）
        if suggested_tags:
            await auto_assign_tags(db, current_user.family_id, entry_id, suggested_tags)

        item.action = "imported"
        item.matched_txn_id = entry_id
        created += 1

    imp.status = "confirmed"
    imp.new_count = created
    await db.commit()

    msg = f"成功导入 {created} 条交易"
    if skipped:
        msg += f"，跳过 {skipped} 条(金额为0)"
    return {"message": msg, "imported": created, "skipped": skipped}


@router.delete("/api/imports/{import_id}", status_code=204)
async def delete_import(
    import_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """删除导入记录及其关联数据"""
    result = await db.execute(
        select(BillImport).where(
            BillImport.id == import_id,
            BillImport.family_id == current_user.family_id,
        )
    )
    imp = result.scalar_one_or_none()
    if not imp:
        raise HTTPException(status_code=404, detail="导入记录不存在")

    # 先删除关联的交易记录
    from sqlalchemy import delete as sql_delete

    await db.execute(
        sql_delete(Transaction).where(
            Transaction.import_id == import_id,
            Transaction.family_id == current_user.family_id,
        )
    )

    # 再删除关联的明细记录
    await db.execute(
        sql_delete(BillImportItem).where(BillImportItem.import_id == import_id)
    )

    await db.delete(imp)
    await db.commit()
