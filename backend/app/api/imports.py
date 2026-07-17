import csv
import io
import json
from datetime import datetime

import structlog
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.database import get_db
from app.models.bill_import import BillImport, BillImportItem
from app.models.channel import PaymentChannel
from app.models.transaction import Transaction
from app.models.user import User

logger = structlog.get_logger()
router = APIRouter(tags=["账单导入"])


def detect_and_decode(content_bytes: bytes) -> str:
    """自动检测编码并解码"""
    for encoding in ["utf-8-sig", "utf-8", "gbk", "gb18030", "gb2312"]:
        try:
            return content_bytes.decode(encoding)
        except (UnicodeDecodeError, LookupError):
            continue
    return content_bytes.decode("utf-8", errors="ignore")


# 已知平台列表（用于识别"交易对方"中的平台）
KNOWN_PLATFORMS = {
    "淘宝", "淘宝闪购", "天猫", "京东", "拼多多", "美团", "饿了么",
    "抖音", "小红书", "得物", "唯品会", "闲鱼", "亚马逊",
    "苏宁易购", "当当", "网易严选", "小米商城", "华为商城",
}


def identify_platform_and_merchant(counterparty: str, description: str, source: str) -> tuple[str, str]:
    """识别平台和商户

    返回: (platform, merchant)
    """
    # 检查"交易对方"是否是已知平台
    for platform in KNOWN_PLATFORMS:
        if platform in counterparty:
            # 如果是平台，尝试从"商品名称"中提取真实商户
            # 格式通常是: "商户名-商品描述" 或 "商户名(分店)"
            merchant = counterparty  # 默认用平台名

            # 尝试从描述中提取商户
            if description:
                # 模式1: "商户名(分店)外卖订单"
                if "外卖订单" in description:
                    merchant = description.replace("外卖订单", "").strip()
                # 模式2: "商户名-商品描述"
                elif "-" in description:
                    parts = description.split("-", 1)
                    if len(parts[0]) > 2 and len(parts[0]) < 20:  # 合理的商户名长度
                        merchant = parts[0].strip()
                # 模式3: "商户名(分店)"
                elif "(" in description and ")" in description:
                    match = description[:description.index(")") + 1]
                    if len(match) > 2:
                        merchant = match.strip()

            return platform, merchant

    # 不是已知平台
    if source == "alipay":
        return "支付宝", counterparty
    elif source == "wechat":
        return "微信", counterparty
    else:
        return "线下", counterparty


def parse_alipay_csv(content: str) -> tuple[list[dict], dict]:
    """解析支付宝 CSV 账单

    返回: (交易列表, 元数据)
    元数据包含: platform(平台), has_payment_method(是否包含具体支付方式)
    """
    lines = content.strip().split("\n")
    header_idx = -1
    for i, line in enumerate(lines):
        if "交易" in line and ("对方" in line or "金额" in line):
            header_idx = i
            break
    if header_idx == -1:
        raise ValueError("无法识别支付宝账单格式")

    headers = [h.strip() for h in lines[header_idx].split(",") if h.strip()]
    reader = csv.DictReader(lines[header_idx:])
    items = []

    # 检查是否有"收/付款方式"列（新版支付宝可能有）
    has_payment_method = "收/付款方式" in headers or "付款方式" in headers

    for row in reader:
        try:
            # 金额
            amount_key = next((k for k in row if k and "金额" in k), None)
            if not amount_key or not row.get(amount_key):
                continue
            amount = float(row[amount_key].replace(",", "").replace("¥", "").strip())

            # 收/支
            dir_key = next((k for k in row if k and "收" in k and "支" in k), None)
            direction = row.get(dir_key, "").strip() if dir_key else ""
            if "不计收支" in direction:
                continue
            txn_type = "expense" if "支出" in direction else "income"

            # 状态 - 跳过退款
            status_key = next((k for k in row if k and "状态" in k), None)
            status_val = row.get(status_key, "").strip() if status_key else ""
            if "退款" in status_val:
                continue

            # 交易号
            order_key = next((k for k in row if k and "交易号" in k and "商家" not in k), None)
            order_no = row.get(order_key, "").strip() if order_key else ""

            # 交易时间
            time_key = next((k for k in row if k and ("创建时间" in k or "付款时间" in k or "交易时间" in k)), None)
            txn_time = row.get(time_key, "").strip() if time_key else ""

            # 交易对方(商户)
            merchant_key = next((k for k in row if k and "对方" in k), None)
            merchant = row.get(merchant_key, "").strip() if merchant_key else ""

            # 商品名称
            desc_key = next((k for k in row if k and ("商品" in k or "名称" in k)), None)
            description = row.get(desc_key, "").strip() if desc_key else ""

            # 交易来源地(平台) - 支付宝网站/APP等
            platform_key = next((k for k in row if k and "来源" in k), None)
            platform = row.get(platform_key, "").strip() if platform_key else ""

            # 收/付款方式(具体资金来源) - 如果有的话
            payment_key = next((k for k in row if k and ("付款方式" in k or "收/付款方式" in k)), None)
            payment_method = row.get(payment_key, "").strip() if payment_key else ""

            # 资金状态
            fund_key = next((k for k in row if k and "资金" in k), None)
            fund_status = row.get(fund_key, "").strip() if fund_key else ""

            # 类型(交易方式)
            type_key = next((k for k in row if k and k == "类型"), None)
            txn_method = row.get(type_key, "").strip() if type_key else ""

            # 尝试从描述推断资金来源
            inferred_account = ""
            if not payment_method:
                # 从商品名称或备注推断
                combined = f"{description} {merchant}"
                if "花呗" in combined:
                    inferred_account = "花呗"
                elif "余额宝" in combined:
                    inferred_account = "余额宝"
                elif "借呗" in combined:
                    inferred_account = "借呗"
                elif "信用卡" in combined:
                    inferred_account = "信用卡"

            # 智能识别平台和商户
            detected_platform, detected_merchant = identify_platform_and_merchant(
                merchant, description, "alipay"
            )

            items.append({
                "order_no": order_no,
                "transaction_time": txn_time,
                "merchant": detected_merchant,  # 使用识别后的商户
                "description": description,
                "amount": int(amount * 100),  # 转为分
                "type": txn_type,
                "platform": detected_platform,  # 使用识别后的平台
                "platform_raw": platform,  # 保留原始来源地
                "payment_method": payment_method or inferred_account,
                "fund_status": fund_status,
                "txn_method": txn_method,
            })
        except Exception as e:
            logger.warning("parse_alipay_row_error", error=str(e))

    meta = {
        "platform": "支付宝",
        "has_payment_method": has_payment_method,
        "detected_methods": list(set(i["payment_method"] for i in items if i.get("payment_method"))),
    }
    return items, meta


def parse_wechat_csv(content: str) -> tuple[list[dict], dict]:
    """解析微信 CSV 账单"""
    lines = content.strip().split("\n")
    header_idx = -1
    for i, line in enumerate(lines):
        if "交易时间" in line and "交易对方" in line:
            header_idx = i
            break
    if header_idx == -1:
        raise ValueError("无法识别微信账单格式")

    reader = csv.DictReader(lines[header_idx:])
    items = []
    methods = set()

    for row in reader:
        try:
            amount_str = row.get("金额(元)", "0").replace(",", "").replace("¥", "").strip()
            amount = float(amount_str)
            direction = row.get("收/支", "").strip()
            if "不计收支" in direction:
                continue
            txn_type = "expense" if "支出" in direction else "income"
            status = row.get("当前状态", "").strip()
            if "已退款" in status or "退款" in status:
                continue

            # 微信账单有明确的"支付方式"列
            payment_method = row.get("支付方式", "").strip()
            if payment_method:
                methods.add(payment_method)

            # 智能识别平台和商户
            merchant = row.get("交易对方", "").strip()
            description = row.get("商品", "").strip()
            detected_platform, detected_merchant = identify_platform_and_merchant(
                merchant, description, "wechat"
            )

            items.append({
                "order_no": row.get("交易单号", "").strip(),
                "transaction_time": row.get("交易时间", "").strip(),
                "merchant": detected_merchant,
                "description": description,
                "amount": int(amount * 100),
                "type": txn_type,
                "platform": detected_platform,
                "payment_method": payment_method,
            })
        except Exception as e:
            logger.warning("parse_wechat_row_error", error=str(e))

    meta = {
        "platform": "微信",
        "has_payment_method": True,  # 微信账单总是有支付方式
        "detected_methods": list(methods),
    }
    return items, meta


def parse_excel(content: bytes) -> tuple[list[dict], dict]:
    """解析 Excel 账单"""
    try:
        from openpyxl import load_workbook
    except ImportError:
        raise HTTPException(status_code=500, detail="服务器未安装 openpyxl")

    wb = load_workbook(io.BytesIO(content), read_only=True)
    ws = wb.active
    rows = list(ws.iter_rows(values_only=True))
    if not rows:
        return [], {}

    header_idx = -1
    for i, row in enumerate(rows):
        row_str = " ".join(str(c) for c in row if c)
        if "交易" in row_str and ("对方" in row_str or "金额" in row_str):
            header_idx = i
            break

    if header_idx == -1:
        wb.close()
        raise ValueError("无法识别 Excel 账单格式")

    headers = [str(c).strip() if c else "" for c in rows[header_idx]]
    items = []

    for row in rows[header_idx + 1:]:
        data = {}
        for j, val in enumerate(row):
            if j < len(headers) and headers[j]:
                data[headers[j]] = val

        amount_key = next((k for k in data if "金额" in k), None)
        if not amount_key or not data.get(amount_key):
            continue

        try:
            amount_val = data.get(amount_key, 0)
            if isinstance(amount_val, str):
                amount_val = float(amount_val.replace(",", "").replace("¥", ""))
            amount = float(amount_val)

            dir_key = next((k for k in data if "收" in k and "支" in k), None)
            direction = str(data.get(dir_key, "")) if dir_key else ""
            if "不计收支" in direction:
                continue
            txn_type = "expense" if "支出" in direction else "income"

            merchant_key = next((k for k in data if "对方" in k), None)
            desc_key = next((k for k in data if "商品" in k or "名称" in k), None)
            time_key = next((k for k in data if "时间" in k), None)

            items.append({
                "order_no": str(data.get("交易号", "")),
                "transaction_time": str(data.get(time_key, "")) if time_key else "",
                "merchant": str(data.get(merchant_key, "")) if merchant_key else "",
                "description": str(data.get(desc_key, "")) if desc_key else "",
                "amount": int(amount * 100),
                "type": txn_type,
                "platform": "",
                "payment_method": "",
            })
        except Exception:
            pass

    wb.close()
    return items, {"platform": "unknown", "has_payment_method": False, "detected_methods": []}


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
                items, meta = parse_alipay_csv(content_str)
            file_format = "csv"

        elif ext in ("xlsx", "xls"):
            items, meta = parse_excel(content_bytes)
            file_format = "xlsx"
        else:
            raise HTTPException(status_code=400, detail=f"不支持的文件格式: {ext}")

    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error("import_parse_error", error=str(e))
        raise HTTPException(status_code=500, detail=f"解析失败: {str(e)}")

    # 去重
    order_nos = [i["order_no"] for i in items if i.get("order_no")]
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
            if row and row.get("order_no"):
                existing_orders.add(row["order_no"])

    new_items = [i for i in items if not i.get("order_no") or i["order_no"] not in existing_orders]
    skipped_dup = len(items) - len(new_items)

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
        "preview": new_items[:30],
    }


@router.get("/api/imports")
async def list_imports(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(BillImport)
        .where(BillImport.family_id == current_user.family_id)
        .order_by(BillImport.created_at.desc())
    )
    rows = result.scalars().all()
    return [
        {
            "id": i.id, "family_id": i.family_id, "book_id": i.book_id,
            "source": i.source, "file_format": i.file_format, "status": i.status,
            "total_rows": i.total_rows, "parsed_count": i.parsed_count,
            "matched_count": i.matched_count, "new_count": i.new_count,
            "created_at": i.created_at.isoformat() if i.created_at else None,
        }
        for i in rows
    ]


@router.get("/api/imports/{import_id}")
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
    return imp


@router.get("/api/imports/{import_id}/items")
async def list_import_items(
    import_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(BillImportItem).where(BillImportItem.import_id == import_id)
    )
    rows = result.scalars().all()
    return [
        {
            "id": i.id, "import_id": i.import_id, "raw_data": i.raw_data,
            "parsed_amount": i.parsed_amount, "parsed_merchant": i.parsed_merchant,
            "action": i.action, "matched_txn_id": i.matched_txn_id,
        }
        for i in rows
    ]


@router.post("/api/imports/{import_id}/confirm")
async def confirm_import(
    import_id: int,
    body: dict | None = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """确认导入

    body: {
        "default_account_id": 1,  // 默认账户ID（用于没有明确支付方式的交易）
        "method_account_map": {   // 支付方式→账户ID映射
            "花呗": 2,
            "工商银行信用卡": 3,
            "零钱": 4
        }
    }
    """
    from sqlalchemy import text

    if body is None:
        body = {}

    default_account_id = body.get("default_account_id")
    method_account_map = body.get("method_account_map", {})

    result = await db.execute(
        select(BillImport).where(
            BillImport.id == import_id,
            BillImport.family_id == current_user.family_id,
        )
    )
    imp = result.scalar_one_or_none()
    if not imp:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="导入记录不存在")
    if imp.status == "confirmed":
        raise HTTPException(status_code=400, detail="该导入已确认")

    items_result = await db.execute(
        select(BillImportItem).where(
            BillImportItem.import_id == import_id,
            BillImportItem.action == "pending",
        )
    )
    items = items_result.scalars().all()

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
        txn_time = datetime.now()
        if isinstance(txn_time_str, str) and txn_time_str:
            for fmt in ["%Y-%m-%d %H:%M:%S", "%Y/%m/%d %H:%M", "%Y-%m-%d %H:%M", "%Y-%m-%d"]:
                try:
                    txn_time = datetime.strptime(txn_time_str.strip(), fmt)
                    break
                except ValueError:
                    continue

        # 确定账户ID：优先用 method_account_map，否则用 default_account_id
        payment_method = raw.get("payment_method", "")
        account_id = None
        if payment_method and payment_method in method_account_map:
            account_id = method_account_map[payment_method]
        elif default_account_id:
            account_id = default_account_id

        # 查找平台ID（使用模糊匹配，因为检测到的可能是"淘宝闪购"而数据库中是"淘宝"）
        platform_name = raw.get("platform", "")
        platform_id = None
        if platform_name:
            from app.models.platform import Platform
            # 先尝试精确匹配
            platform_result = await db.execute(
                select(Platform.id).where(Platform.name == platform_name).limit(1)
            )
            platform_id = platform_result.scalar()
            # 如果没找到，尝试模糊匹配
            if not platform_id:
                platform_result = await db.execute(
                    select(Platform.id).where(Platform.name.contains(platform_name[:2])).limit(1)
                )
                platform_id = platform_result.scalar()

        # 查找支付渠道ID（根据平台或来源推断）
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

        txn = Transaction(
            family_id=current_user.family_id,
            book_id=imp.book_id,
            entry_id=entry_id,
            entry_side="debit",
            type=txn_type,
            amount=amount,
            currency="CNY",
            merchant_name=item.parsed_merchant or raw.get("merchant"),
            description=raw.get("description"),
            transaction_time=txn_time,
            payment_account_id=account_id,
            payment_channel_id=channel_id,
            platform_id=platform_id,
            recorded_by=current_user.id,
            paid_by=current_user.id,
            completion_status="complete",
        )
        db.add(txn)
        item.action = "imported"
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
    result = await db.execute(
        select(BillImport).where(
            BillImport.id == import_id,
            BillImport.family_id == current_user.family_id,
        )
    )
    imp = result.scalar_one_or_none()
    if not imp:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="导入记录不存在")

    # 先删除关联的明细记录（使用 bulk delete 避免逐条查询）
    from sqlalchemy import delete as sql_delete
    await db.execute(
        sql_delete(BillImportItem).where(BillImportItem.import_id == import_id)
    )

    await db.delete(imp)
    await db.commit()
