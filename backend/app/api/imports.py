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
from app.parsers import detect_and_decode, parse_alipay_csv, parse_wechat_csv, parse_excel, parse_icbc_pdf, parse_icbc_csv
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
                # 检测来源
                if "明细查询文件下载" in content_str[:500] or "卡号:" in content_str[:500]:
                    source = "icbc"
                elif "支付宝" in content_str[:500] or "交易号" in content_str[:1000]:
                    source = "alipay"
                elif "微信" in content_str[:500] or "交易单号" in content_str[:1000]:
                    source = "wechat"
                else:
                    source = "alipay"

            if source == "alipay":
                items, meta = parse_alipay_csv(content_str)
            elif source == "wechat":
                items, meta = parse_wechat_csv(content_str)
            elif source == "icbc":
                items, meta = parse_icbc_csv(content_str)
            else:
                raise ValueError(f"不支持的 CSV 来源: {source}")
            file_format = "csv"
        elif ext == "txt":
            content_str = detect_and_decode(content_bytes)
            # TXT 文件可能是工行明细（^ 分隔）
            if "明细查询文件下载" in content_str[:500] or "^" in content_str[:1000]:
                items, meta = parse_icbc_csv(content_str)
                source = "icbc"
            else:
                raise ValueError("无法识别 TXT 文件格式")
            file_format = "txt"
        elif ext in ("xlsx", "xls"):
            items, meta = parse_excel(content_bytes)
            # 从解析器返回的 meta 中获取实际来源
            detected_platform = meta.get("platform", "")
            if detected_platform == "微信":
                source = "wechat"
            elif detected_platform == "支付宝":
                source = "alipay"
            # 保留用户选择的 source（如果不是 auto）
            elif source == "auto":
                source = "auto"
            file_format = "xlsx"
        elif ext == "pdf":
            items, meta = parse_icbc_pdf(content_bytes)
            source = "icbc"
            file_format = "pdf"
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

        # 本地关键词规则分类（上传阶段快速分类，AI 在确认阶段使用）
        suggested_cat, auto_tags = auto_categorize(merchant, description, txn_type, platform, pm)

        # 写入分类建议
        if suggested_cat:
            cat_id = category_names.get(suggested_cat)
            if cat_id:
                item["suggested_category_id"] = cat_id
                item["suggested_category_name"] = suggested_cat

        # 写入标签建议
        if auto_tags:
            item["suggested_tags"] = auto_tags

        # 5. 自动匹配账户（转账类型不匹配，由确认时处理目标账户）
        if pm and pm in method_matches and txn_type != "transfer":
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
    body: dict | None = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """确认导入，创建交易记录"""
    from sqlalchemy import text

    # 从请求体获取账户映射
    default_account_id = (body or {}).get("default_account_id")
    method_account_map = (body or {}).get("method_account_map", {})

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

    # 检查是否配置了 AI
    use_ai = False
    ai_service = None
    if current_user.family_id:
        from app.models.user import Family
        from app.services.ai_service import get_ai_service
        family_result = await db.execute(
            select(Family.settings).where(Family.id == current_user.family_id)
        )
        family_row = family_result.first()
        family_settings = family_row[0] if family_row else {}
        if family_settings and family_settings.get("ai", {}).get("enabled"):
            ai_service = get_ai_service(family_settings=family_settings)
            if ai_service:
                use_ai = True

    # 如果启用了 AI，先批量分类未匹配的交易
    ai_results = {}
    if use_ai and ai_service:
        # 收集需要 AI 分类的交易
        pending_txns = []
        pending_indices = []
        for i, item in enumerate(items):
            raw = item.raw_data
            merchant = raw.get("merchant", "")
            description = raw.get("description", "")
            # 只对没有分类建议的交易调用 AI
            if not raw.get("suggested_category_id") and (merchant or description):
                pending_txns.append({
                    "merchant": merchant,
                    "description": description,
                    "amount": (item.parsed_amount or raw.get("amount", 0)) / 100,
                    "type": raw.get("type", "expense"),
                })
                pending_indices.append(i)

        # 批量调用 AI（每次最多50条）
        categories = [{"id": c.id, "name": c.name, "level": c.level} for c in cats_result.scalars()]
        for batch_start in range(0, len(pending_txns), 50):
            batch = pending_txns[batch_start:batch_start+50]
            batch_indices = pending_indices[batch_start:batch_start+50]
            try:
                results = await ai_service.categorize_batch(batch, categories)
                if results:
                    for j, result in enumerate(results):
                        if j < len(batch_indices) and result.get("category_name"):
                            ai_results[batch_indices[j]] = result["category_name"]
            except Exception:
                pass

    seq_result = await db.execute(text("SELECT nextval('transactions_id_seq')"))
    base_entry_id = seq_result.scalar()

    created = 0
    skipped = 0
    unmatched_xiaohebao = set()  # 收集未匹配的小荷包名称
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

        account_id = None
        txn_type = raw.get("type", "expense")

        # 非转账类型：使用建议的账户（转账也需要来源账户，提前解析）
        suggested_account_id = raw.get("suggested_account_id")
        if suggested_account_id:
            account_id = suggested_account_id
        elif method_account_map:
            pm = raw.get("payment_method", "")
            account_id = method_account_map.get(pm)
        elif default_account_id:
            account_id = default_account_id

        # 转账类型：识别目标账户
        destination_account_id = None
        if txn_type == "transfer":
            counterparty = raw.get("merchant", "") or ""
            description = raw.get("description", "") or ""
            pm = raw.get("payment_method", "") or ""
            search_text = f"{counterparty} {description} {pm}"

            # 小荷包特殊处理：提取括号中的名称，精确匹配账户
            import re
            xiaohebao_match = re.search(r'小荷包[（(]([^）)]+)[）)]', search_text)
            if xiaohebao_match:
                xiaohebao_name = xiaohebao_match.group(1)
                # 查找名称包含小荷包名的账户
                dest_result = await db.execute(
                    select(PaymentAccount.id).where(
                        PaymentAccount.family_id == current_user.family_id,
                        PaymentAccount.type_code == "alipay_xiaoheibao",
                        PaymentAccount.name.ilike(f"%{xiaohebao_name}%"),
                    ).limit(1)
                )
                destination_account_id = dest_result.scalar()
                # 如果没找到精确匹配，记录未匹配的小荷包名称
                if not destination_account_id:
                    unmatched_xiaohebao.add(xiaohebao_name)
            else:
                # 其他转账类型：花呗、余额宝、零钱通等
                DESTINATION_PATTERNS = {
                    "花呗": "alipay_huabei",
                    "余额宝": "alipay_yuebao",
                    "零钱通": "wechat_lingqian",
                    "借呗": "alipay_jiebei",
                }
                for keyword, type_code in DESTINATION_PATTERNS.items():
                    if keyword in search_text:
                        dest_result = await db.execute(
                            select(PaymentAccount.id).where(
                                PaymentAccount.family_id == current_user.family_id,
                                PaymentAccount.type_code == type_code,
                            ).limit(1)
                        )
                        destination_account_id = dest_result.scalar()
                        if destination_account_id:
                            break

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

        # 查找支付渠道ID（支持自动识别）
        channel_id = None
        source_for_channel = imp.source

        # 从交易场所/摘要推断实际支付渠道（工行账单中 venue 字段很重要）
        venue = raw.get("venue", "") or raw.get("交易场所", "")
        summary = raw.get("summary", "") or raw.get("摘要", "")

        if "支付宝" in venue or "支付宝" in summary:
            source_for_channel = "alipay"
        elif "财付通" in venue or "微信" in venue or "微信" in summary:
            source_for_channel = "wechat"
        elif source_for_channel == "auto":
            platform_name = raw.get("platform", "")
            if platform_name == "微信" or "微信" in str(raw.get("payment_method", "")):
                source_for_channel = "wechat"
            elif platform_name == "支付宝":
                source_for_channel = "alipay"

        if source_for_channel in ("alipay",):
            channel_result = await db.execute(
                select(PaymentChannel.id).where(PaymentChannel.name == "支付宝").limit(1)
            )
            channel_id = channel_result.scalar()
        elif source_for_channel in ("wechat",):
            channel_result = await db.execute(
                select(PaymentChannel.id).where(PaymentChannel.name == "微信支付").limit(1)
            )
            channel_id = channel_result.scalar()
        elif source_for_channel == "icbc":
            channel_result = await db.execute(
                select(PaymentChannel.id).where(PaymentChannel.name == "银行转账").limit(1)
            )
            channel_id = channel_result.scalar()

        # 使用自动分类建议，否则实时分类
        category_id = raw.get("suggested_category_id")
        suggested_tags = raw.get("suggested_tags", [])

        # 先检查批量AI分类结果
        item_idx = items.index(item) if item in items else -1
        if not category_id and item_idx in ai_results:
            cat_name = ai_results[item_idx]
            cat_id = _category_name_map.get(cat_name)
            if cat_id:
                category_id = cat_id

        if not category_id:
            merchant = raw.get("merchant", "")
            description = raw.get("description", "")
            platform = raw.get("platform", "")
            pm = raw.get("payment_method", "")

            # 转账类型不参与自动分类，只打"转账"标签
            if txn_type == "transfer":
                category_id = _category_name_map.get("转账")
                suggested_tags = ["转账"]
            else:
                # 本地规则分类（跳过单独AI调用，已使用批量结果）
                cat_name, auto_tags = auto_categorize(merchant, description, txn_type, platform, pm)

                if cat_name:
                    cat_id = _category_name_map.get(cat_name)
                    if cat_id:
                        category_id = cat_id
                if auto_tags:
                    suggested_tags = auto_tags

        # === 去重合并：查找同日同金额的已有交易 ===
        from sqlalchemy import and_, func as sa_func, or_
        txn_date = txn_time.date()

        # 先尝试精确匹配商户名
        existing_txn = await db.execute(
            select(Transaction).where(
                Transaction.family_id == current_user.family_id,
                Transaction.entry_side == "debit",
                Transaction.is_deleted == False,
                Transaction.amount == amount,
                sa_func.date(Transaction.transaction_time) == txn_date,
                *([Transaction.merchant_name == item.parsed_merchant] if item.parsed_merchant else []),
            ).limit(1)
        )
        existing = existing_txn.scalar_one_or_none()

        # 精确匹配失败，尝试模糊匹配（银行账单描述包含支付宝商户名）
        if not existing and item.parsed_merchant:
            fuzzy_txn = await db.execute(
                select(Transaction).where(
                    Transaction.family_id == current_user.family_id,
                    Transaction.entry_side == "debit",
                    Transaction.is_deleted == False,
                    Transaction.amount == amount,
                    sa_func.date(Transaction.transaction_time) == txn_date,
                    or_(
                        Transaction.merchant_name.ilike(f"%{item.parsed_merchant}%"),
                        Transaction.description.ilike(f"%{item.parsed_merchant}%"),
                    ),
                ).limit(1)
            )
            existing = fuzzy_txn.scalar_one_or_none()

        # 关键：如果已有记录是transfer类型，当前记录是expense类型，跳过合并
        # 保留支付宝的transfer记录，不要用银行的expense记录覆盖
        if existing and existing.type == "transfer" and txn_type == "expense":
            item.action = "skipped"
            item.matched_txn_id = existing.entry_id
            skipped += 1
            continue

        if existing:
            # 合并：补充已有记录缺失的字段
            updated = False
            if channel_id and not existing.payment_channel_id:
                existing.payment_channel_id = channel_id
                updated = True
            if platform_id and not existing.platform_id:
                existing.platform_id = platform_id
                updated = True
            if category_id and not existing.category_id:
                existing.category_id = category_id
                updated = True
            if not existing.import_id:
                existing.import_id = imp.id
                updated = True

            # 转账类型：更新目标账户（debit侧）
            if txn_type == "transfer" and destination_account_id and not existing.payment_account_id:
                existing.payment_account_id = destination_account_id
                updated = True
            elif account_id and not existing.payment_account_id:
                existing.payment_account_id = account_id
                updated = True

            # 同步更新 credit 行的 payment_account_id（来源账户）
            if account_id and updated:
                credit_result = await db.execute(
                    select(Transaction).where(
                        Transaction.entry_id == existing.entry_id,
                        Transaction.entry_side == "credit",
                    )
                )
                credit_row = credit_result.scalar_one_or_none()
                if credit_row and not credit_row.payment_account_id:
                    credit_row.payment_account_id = account_id

            # 打标签
            if suggested_tags:
                await auto_assign_tags(db, current_user.family_id, existing.entry_id, suggested_tags)

            item.action = "imported"
            item.matched_txn_id = existing.entry_id
            created += 1
            continue

        # 双式记账（无匹配，创建新记录）
        if txn_type == "transfer":
            debit_account = destination_account_id
            credit_account = account_id
        else:
            debit_account = account_id
            credit_account = account_id

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
            payment_account_id=debit_account,
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
            payment_account_id=credit_account,
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
        msg += f"，跳过 {skipped} 条(金额为0或已存在transfer记录)"
    result = {"message": msg, "imported": created, "skipped": skipped}
    if unmatched_xiaohebao:
        result["unmatched_xiaohebao"] = list(unmatched_xiaohebao)
        result["message"] += f"，发现 {len(unmatched_xiaohebao)} 个小荷包账户未创建"
    return result


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
