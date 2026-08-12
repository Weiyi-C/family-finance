"""建设银行储蓄卡 XLS 账单解析器"""

import re

from .utils import identify_platform_and_merchant


def parse_ccb_debit_xls(content: bytes) -> tuple[list[dict], dict]:
    """解析建设银行储蓄卡 XLS 明细

    格式特点：
    - 前4行为元信息（银行名称、开户机构、币种、账号），第5行为表头
    - 表头：记账日, 交易日期, 交易时间, 支出, 收入, 账户余额, 币种, 摘要, 对方账号, 对方户名, 交易地点
    - 支出/收入是分开的两列，0.00 表示无
    - 需要 xlrd 库

    Returns:
        (items, meta)
    """
    import xlrd
    from io import BytesIO

    wb = xlrd.open_workbook(file_contents=content)
    ws = wb.sheet_by_index(0)

    # 从元信息中提取卡号
    card_number = ""
    for row_idx in range(min(5, ws.nrows)):
        for col_idx in range(ws.ncols):
            cell_val = str(ws.cell_value(row_idx, col_idx))
            # 匹配账号格式（纯数字16-19位）
            acct_match = re.search(r"\b(\d{16,19})\b", cell_val)
            if acct_match:
                card_number = acct_match.group(1)

    # 查找表头行（包含"记账日"和"摘要"的行）
    header_idx = -1
    headers = []
    for row_idx in range(min(10, ws.nrows)):
        row_vals = [str(ws.cell_value(row_idx, col_idx)).strip() for col_idx in range(ws.ncols)]
        row_str = " ".join(row_vals)
        if "记账日" in row_str and "摘要" in row_str:
            header_idx = row_idx
            headers = row_vals
            break

    if header_idx == -1:
        raise ValueError("无法识别建设银行储蓄卡账单格式")

    items = []
    methods = set()

    for row_idx in range(header_idx + 1, ws.nrows):
        try:
            # 构建 row dict
            row = {}
            for col_idx in range(ws.ncols):
                if col_idx < len(headers) and headers[col_idx]:
                    cell = ws.cell_value(row_idx, col_idx)
                    row[headers[col_idx]] = cell

            # 交易日期
            txn_date_raw = row.get("交易日期", "")
            if isinstance(txn_date_raw, float):
                # Excel 日期序列号
                txn_date_tuple = xlrd.xldate_as_tuple(txn_date_raw, wb.datemode)
                txn_date = f"{txn_date_tuple[0]:04d}-{txn_date_tuple[1]:02d}-{txn_date_tuple[2]:02d}"
            else:
                txn_date = str(txn_date_raw).strip()
                # 格式可能是 20260601 或 2026-06-01
                if re.match(r"\d{8}$", txn_date):
                    txn_date = f"{txn_date[:4]}-{txn_date[4:6]}-{txn_date[6:8]}"

            if not txn_date or not re.match(r"\d{4}-\d{2}-\d{2}", txn_date):
                continue

            # 交易时间
            txn_time_raw = row.get("交易时间", "")
            if isinstance(txn_time_raw, float):
                # Excel 时间序列号（小数部分）
                time_tuple = xlrd.xldate_as_tuple(txn_time_raw, wb.datemode)
                txn_time = f"{txn_date} {time_tuple[3]:02d}:{time_tuple[4]:02d}:{time_tuple[5]:02d}"
            else:
                txn_time_str = str(txn_time_raw).strip()
                if txn_time_str and re.match(r"\d{2}:\d{2}:\d{2}", txn_time_str):
                    txn_time = f"{txn_date} {txn_time_str}"
                else:
                    txn_time = txn_date

            # 支出/收入（两列）
            expense_val = row.get("支出", 0)
            income_val = row.get("收入", 0)

            if isinstance(expense_val, str):
                expense_val = expense_val.replace(",", "").strip()
                expense_val = float(expense_val) if expense_val and expense_val != "0.00" else 0
            if isinstance(income_val, str):
                income_val = income_val.replace(",", "").strip()
                income_val = float(income_val) if income_val and income_val != "0.00" else 0

            expense = float(expense_val or 0)
            income = float(income_val or 0)

            if expense > 0:
                amount = expense
                txn_type = "expense"
            elif income > 0:
                amount = income
                txn_type = "income"
            else:
                continue

            # 余额
            balance_val = row.get("账户余额", 0)
            if isinstance(balance_val, str):
                balance_val = balance_val.replace(",", "").strip()
                balance = float(balance_val) if balance_val else 0
            else:
                balance = float(balance_val or 0)

            # 摘要
            summary = str(row.get("摘要", "")).strip()

            # 对方账号、对方户名
            counterparty_acct = str(row.get("对方账号", "")).strip()
            counterparty = str(row.get("对方户名", "")).strip()

            # 交易地点（包含平台信息）
            venue = str(row.get("交易地点", "")).strip()

            # 构建描述
            description_parts = []
            if summary:
                description_parts.append(summary)
            if venue and venue not in ("", "0"):
                description_parts.append(venue)
            description = " - ".join(description_parts) if description_parts else ""

            # 平台和商户识别
            # 交易地点格式：支付宝-支付宝-理财-蚂蚁（杭州）基金销售有限公司
            platform_source = venue if venue and venue != "0" else summary
            platform, merchant = identify_platform_and_merchant(
                counterparty or platform_source, description, "ccb"
            )

            # 如果交易地点以已知平台开头，覆盖平台
            if venue and venue != "0":
                for known in ["支付宝", "微信", "财付通", "京东", "美团", "抖音"]:
                    if venue.startswith(known):
                        platform = known
                        break

            # 如果商户名为空，使用摘要或对方户名
            if not merchant or merchant == "线下":
                merchant = counterparty or summary or "建设银行"

            # 转账类型识别
            transfer_keywords = ["余额宝", "小荷包", "零钱通", "自动攒", "笔笔攒"]
            if any(kw in venue or kw in summary for kw in transfer_keywords):
                txn_type = "transfer"
            elif summary in ("理财产品赎回",) and counterparty:
                txn_type = "transfer"
            elif any(kw in summary for kw in ["转入", "转出"]):
                txn_type = "transfer"

            # 支付方式
            card_tail = card_number[-4:] if card_number else ""
            payment_method = f"建设银行储蓄卡({card_tail})" if card_tail else "建设银行储蓄卡"
            methods.add(payment_method)

            items.append({
                "order_no": f"CCB_{txn_date.replace('-', '')}_{int(amount * 100)}_{hash(f'{txn_date}{amount}{counterparty}') % 10000:04d}",
                "transaction_time": txn_time,
                "merchant": merchant,
                "description": description,
                "amount": int(amount * 100),
                "type": txn_type,
                "platform": platform,
                "payment_method": payment_method,
                "balance": int(balance * 100),
                "summary": summary,
                "venue": venue if venue != "0" else "",
                "counterparty": counterparty,
                "counterparty_account": counterparty_acct,
            })
        except Exception:
            continue

    meta = {
        "platform": "建设银行",
        "card_number": card_number[-4:] if card_number else "",
        "has_payment_method": True,
        "detected_methods": list(methods),
    }
    return items, meta
