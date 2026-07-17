import csv
import io
import json
from datetime import datetime

import structlog
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, status
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.database import get_db
from app.models.bill_import import BillImport, BillImportItem
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


def parse_alipay_csv(content: str) -> tuple[list[dict], list[str]]:
    """解析支付宝 CSV 账单，返回 (交易列表, 未识别的支付方式列表)"""
    lines = content.strip().split("\n")
    header_idx = -1
    for i, line in enumerate(lines):
        if "交易" in line and ("对方" in line or "金额" in line):
            header_idx = i
            break
    if header_idx == -1:
        raise ValueError("无法识别支付宝账单格式")

    reader = csv.DictReader(lines[header_idx:])
    items = []
    payment_methods = set()

    for row in reader:
        try:
            # 金额
            amount_key = next((k for k in row if k and "金额" in k), None)
            if not amount_key or not row.get(amount_key):
                continue
            amount = int(float(row[amount_key].replace(",", "").replace("¥", "").strip()) * 100)

            # 收/支
            dir_key = next((k for k in row if k and "收" in k and "支" in k), None)
            direction = row.get(dir_key, "") if dir_key else ""
            if "不计收支" in direction:
                continue
            txn_type = "expense" if "支出" in direction else "income"

            # 状态 - 跳过退款
            status_key = next((k for k in row if k and "状态" in k), None)
            status_val = row.get(status_key, "") if status_key else ""
            if "退款" in status_val:
                continue

            # 交易号(用于去重)
            order_key = next((k for k in row if k and "交易号" in k and "商家" not in k), None)
            order_no = row.get(order_key, "").strip() if order_key else ""

            # 商家订单号
            merchant_order_key = next((k for k in row if k and "商家订单号" in k), None)
            merchant_order_no = row.get(merchant_order_key, "").strip() if merchant_order_key else ""

            # 交易时间
            time_key = next((k for k in row if k and ("创建时间" in k or "付款时间" in k or "交易时间" in k)), None)
            txn_time = row.get(time_key, "").strip() if time_key else ""

            # 交易对方(商户)
            merchant_key = next((k for k in row if k and "对方" in k), None)
            merchant = row.get(merchant_key, "").strip() if merchant_key else ""

            # 商品名称
            desc_key = next((k for k in row if k and ("商品" in k or "名称" in k)), None)
            description = row.get(desc_key, "").strip() if desc_key else ""

            # 交易来源地(平台)
            platform_key = next((k for k in row if k and "来源" in k), None)
            platform = row.get(platform_key, "").strip() if platform_key else ""

            # 类型(交易方式)
            type_key = next((k for k in row if k and row.get(k, "").strip() in ["即时到账交易", "转账", "充值", "提现"] or (k == "类型")), None)
            txn_method = row.get(type_key, "").strip() if type_key else ""

            # 资金状态(推断支付渠道)
            fund_key = next((k for k in row if k and "资金" in k), None)
            fund_status = row.get(fund_key, "").strip() if fund_key else ""

            # 支付方式 - 支付宝账单通常不直接列出，但从"交易来源地"和"类型"推断
            # 支付宝网页/APP → 支付宝余额
            # 如果是花呗、余额宝等会有特定标识
            payment_channel = "支付宝"  # 默认支付宝

            payment_methods.add(payment_channel)

            items.append({
                "order_no": order_no,
                "merchant_order_no": merchant_order_no,
                "transaction_time": txn_time,
                "merchant": merchant,
                "description": description,
                "amount": amount,
                "type": txn_type,
                "platform": platform,
                "payment_channel": payment_channel,
                "method": txn_method,
            })
        except Exception as e:
            logger.warning("parse_alipay_row_error", error=str(e))

    return items, list(payment_methods)


def parse_wechat_csv(content: str) -> tuple[list[dict], list[str]]:
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
    payment_methods = set()

    for row in reader:
        try:
            amount_str = row.get("金额(元)", "0").replace(",", "").replace("¥", "").strip()
            amount = int(float(amount_str) * 100)
            direction = row.get("收/支", "")
            if "不计收支" in direction:
                continue
            txn_type = "expense" if "支出" in direction else "income"
            status = row.get("当前状态", "")
            if "已退款" in status or "退款" in status:
                continue

            payment_method = row.get("支付方式", "").strip()
            if payment_method:
                payment_methods.add(payment_method)

            items.append({
                "order_no": row.get("交易单号", "").strip(),
                "transaction_time": row.get("交易时间", "").strip(),
                "merchant": row.get("交易对方", "").strip(),
                "description": row.get("商品", "").strip(),
                "amount": amount,
                "type": txn_type,
                "platform": "微信",
                "payment_channel": payment_method or "微信",
            })
        except Exception as e:
            logger.warning("parse_wechat_row_error", error=str(e))

    return items, list(payment_methods)


def parse_excel(content: bytes) -> tuple[list[dict], list[str]]:
    """解析 Excel 账单"""
    try:
        from openpyxl import load_workbook
    except ImportError:
        raise HTTPException(status_code=500, detail="服务器未安装 openpyxl")

    wb = load_workbook(io.BytesIO(content), read_only=True)
    ws = wb.active
    rows = list(ws.iter_rows(values_only=True))
    if not rows:
        return [], []

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
    payment_methods = set()

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
            amount = int(float(amount_val) * 100)

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
                "amount": amount,
                "type": txn_type,
                "platform": "",
                "payment_channel": "",
            })
        except Exception:
            pass

    wb.close()
    return items, list(payment_methods)


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
                items, payment_methods = parse_alipay_csv(content_str)
            elif source == "wechat":
                items, payment_methods = parse_wechat_csv(content_str)
            else:
                items, payment_methods = parse_alipay_csv(content_str)
            file_format = "csv"

        elif ext in ("xlsx", "xls"):
            items, payment_methods = parse_excel(content_bytes)
            file_format = "xlsx"
        else:
            raise HTTPException(status_code=400, detail=f"不支持的文件格式: {ext}")

    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error("import_parse_error", error=str(e))
        raise HTTPException(status_code=500, detail=f"解析失败: {str(e)}")

    # 去重：检查已存在的交易号
    order_nos = [i["order_no"] for i in items if i.get("order_no")]
    existing_orders = set()
    if order_nos:
        # 查询已导入的交易号
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

    # 过滤已存在的记录
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
        "payment_methods": payment_methods,
        "preview": new_items[:20],
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
    account_mapping: dict[str, int] | None = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """确认导入，将解析的条目转为正式交易

    account_mapping: 支付方式到账户ID的映射，如 {"支付宝": 1, "花呗": 2}
    """
    from sqlalchemy import text

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

    # 获取 entry_id 序列
    seq_result = await db.execute(text("SELECT nextval('entry_id_seq')"))
    base_entry_id = seq_result.scalar()

    created = 0
    skipped = 0
    for item in items:
        raw = item.raw_data
        amount = item.parsed_amount or raw.get("amount", 0)

        # 跳过金额为0的记录
        if not amount or amount <= 0:
            skipped += 1
            item.action = "skipped"
            continue

        entry_id = base_entry_id + created

        # 解析交易时间
        txn_time_str = raw.get("transaction_time", "")
        try:
            if isinstance(txn_time_str, str) and txn_time_str:
                # 尝试多种格式
                for fmt in ["%Y-%m-%d %H:%M:%S", "%Y/%m/%d %H:%M", "%Y-%m-%d %H:%M"]:
                    try:
                        txn_time = datetime.strptime(txn_time_str.strip(), fmt)
                        break
                    except ValueError:
                        continue
                else:
                    txn_time = datetime.now()
            else:
                txn_time = datetime.now()
        except Exception:
            txn_time = datetime.now()

        # 确定账户ID
        payment_channel = raw.get("payment_channel", "")
        account_id = None
        if account_mapping and payment_channel in account_mapping:
            account_id = account_mapping[payment_channel]

        txn_type = raw.get("type", "expense")

        # 创建交易记录
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
    await db.delete(imp)
    await db.commit()
