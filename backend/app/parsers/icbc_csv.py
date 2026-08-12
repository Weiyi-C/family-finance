"""工商银行 CSV/TXT 账单解析器"""

import csv
import re
from io import StringIO


def parse_icbc_csv(content: str) -> tuple[list[dict], dict]:
    """解析工商银行 CSV/TXT 明细

    支持两种格式：
    1. CSV：逗号分隔，带引号
    2. TXT：^ 分隔

    Returns:
        (items, meta)
    """
    lines = content.strip().split("\n")

    # 提取卡号
    card_match = re.search(r"卡号[:：]?\s*(\d{4}\*{4}\d{4})", content)
    card_number = card_match.group(1) if card_match else ""

    # 检测分隔符（CSV 用逗号，TXT 用 ^）
    delimiter = ","
    for line in lines[:10]:
        if "^" in line and line.count("^") > 5:
            delimiter = "^"
            break

    # 查找表头行
    header_idx = -1
    headers = []
    for i, line in enumerate(lines):
        if "交易日期" in line and "摘要" in line:
            header_idx = i
            # 解析表头
            if delimiter == "^":
                headers = [h.strip().lstrip("^") for h in line.split("^") if h.strip()]
            else:
                reader = csv.reader(StringIO(line))
                headers = [h.strip() for h in next(reader)]
            break

    if header_idx == -1:
        raise ValueError("无法识别工商银行明细格式")

    items = []

    for line in lines[header_idx + 1:]:
        line = line.strip()
        if not line or line.startswith("明细查询") or line.startswith("卡号"):
            continue

        # 解析字段
        if delimiter == "^":
            fields = [f.strip() for f in line.split("^") if f.strip()]
        else:
            reader = csv.reader(StringIO(line))
            fields = [f.strip() for f in next(reader)]

        if len(fields) < 8:
            continue

        try:
            txn = _parse_icbc_fields(fields, card_number)
            if txn:
                items.append(txn)
        except Exception:
            continue

    # 判断是储蓄卡还是信用卡（通过第一笔交易的 payment_method）
    is_credit = False
    for item in items:
        if "信用卡" in item.get("payment_method", ""):
            is_credit = True
            break

    card_type = "信用卡" if is_credit else "储蓄卡"
    meta = {
        "platform": "工商银行",
        "card_number": card_number.replace("****", "")[-4:] if card_number else "",
        "has_payment_method": True,
        "detected_methods": [f"工商银行{card_type}({card_number[-4:]})"] if card_number else [],
    }

    return items, meta


def _parse_icbc_fields(fields: list[str], card_number: str) -> dict | None:
    """解析工行明细字段

    支持两种格式：
    - 15列（储蓄卡）：交易日期, 摘要, 交易详情, 交易场所, 国家, 钞/汇,
      交易金额(收入), 交易金额(支出), 交易币种, 记账金额(收入), 记账金额(支出),
      记账币种, 余额, 对方户名, 对方账户
    - 14列（信用卡）：交易日期, 记账日期, 摘要, 交易场所, 国家,
      交易金额(收入), 交易金额(支出), 交易币种, 记账金额(收入), 记账金额(支出),
      记账币种, 余额, 对方户名, 对方账户
    """
    if len(fields) == 14:
        return _parse_icbc_credit_fields(fields, card_number)
    if len(fields) < 15:
        return None

    # 交易日期
    txn_date = fields[0].strip()
    if not re.match(r"\d{4}-\d{2}-\d{2}", txn_date):
        return None

    # 摘要
    summary = fields[1].strip()

    # 交易详情
    detail = fields[2].strip() if len(fields) > 2 else ""

    # 交易场所
    venue = fields[3].strip() if len(fields) > 3 else ""

    # 记账金额（收入/支出）
    income_str = fields[9].strip() if len(fields) > 9 else ""
    expense_str = fields[10].strip() if len(fields) > 10 else ""

    # 解析金额
    income = _parse_amount(income_str)
    expense = _parse_amount(expense_str)

    # 确定金额和类型
    if income > 0:
        amount = income
        txn_type = "income"
    elif expense > 0:
        amount = expense
        txn_type = "expense"
    else:
        return None

    # 余额
    balance_str = fields[12].strip() if len(fields) > 12 else ""
    balance = _parse_amount(balance_str)

    # 对方户名
    counterparty = fields[13].strip() if len(fields) > 13 else ""

    # 对方账号
    counterparty_acct = fields[14].strip() if len(fields) > 14 else ""

    # 构建描述
    description_parts = []
    if summary:
        description_parts.append(summary)
    if detail:
        description_parts.append(detail)
    if venue and venue not in ["手机银行", "网上银行", "批量业务"]:
        description_parts.append(venue)
    description = " - ".join(description_parts) if description_parts else ""

    # 构建商户名
    merchant = counterparty or venue or summary or "工商银行"

    # 复用平台识别逻辑
    from .utils import identify_platform_and_merchant
    platform, detected_merchant = identify_platform_and_merchant(
        counterparty or venue, detail or summary, "icbc"
    )
    # 如果识别出平台，使用识别后的商户名
    if platform not in ("线下", "工商银行"):
        merchant = detected_merchant or merchant

    # 手机银行/网上银行/批量业务 → 工商银行平台
    if venue in ("手机银行", "网上银行", "批量业务") and platform == "线下":
        platform = "工商银行"

    # 识别内部转账（应为transfer类型）
    transfer_venues = ["支付宝-支付宝小荷包", "支付宝-小荷包", "支付宝-余额宝",
                       "财付通-零钱通", "财付通-零钱提现"]
    if any(tv in venue for tv in transfer_venues):
        txn_type = "transfer"
    elif summary in ("预约转账",) and counterparty and not venue:
        # 银行间转账（无交易场所，摘要为预约转账）
        txn_type = "transfer"

    return {
        "order_no": f"ICBC_{txn_date.replace('-', '')}_{amount}_{hash(f'{txn_date}{amount}{counterparty}') % 10000:04d}",
        "transaction_time": txn_date,
        "merchant": merchant,
        "description": description,
        "amount": int(amount * 100),
        "type": txn_type,
        "platform": platform,
        "payment_method": f"工商银行储蓄卡({card_number[-4:]})" if card_number else "工商银行",
        "balance": int(balance * 100),
        "summary": summary,
        "venue": venue,
        "counterparty": counterparty,
        "counterparty_account": counterparty_acct,
    }


def _parse_amount(amount_str: str) -> float:
    """解析金额字符串"""
    if not amount_str or amount_str == "-":
        return 0.0
    # 移除逗号和空格
    cleaned = amount_str.replace(",", "").replace(" ", "").strip()
    try:
        return float(cleaned)
    except ValueError:
        return 0.0


def _parse_icbc_credit_fields(fields: list[str], card_number: str) -> dict | None:
    """解析工行信用卡14列明细

    字段顺序：交易日期, 记账日期, 摘要, 交易场所, 国家,
              交易金额(收入), 交易金额(支出), 交易币种, 记账金额(收入), 记账金额(支出),
              记账币种, 余额, 对方户名, 对方账户
    """
    # 交易日期
    txn_date = fields[0].strip()
    if not re.match(r"\d{4}-\d{2}-\d{2}", txn_date):
        return None

    # 摘要（index 2，跳过记账日期）
    summary = fields[2].strip() if len(fields) > 2 else ""

    # 交易场所（index 3）
    venue = fields[3].strip() if len(fields) > 3 else ""

    # 记账金额（收入/支出）- index 8, 9
    income_str = fields[8].strip() if len(fields) > 8 else ""
    expense_str = fields[9].strip() if len(fields) > 9 else ""

    # 解析金额
    income = _parse_amount(income_str)
    expense = _parse_amount(expense_str)

    # 确定金额和类型
    if income > 0:
        amount = income
        txn_type = "income"
    elif expense > 0:
        amount = expense
        txn_type = "expense"
    else:
        return None

    # 余额（index 11）
    balance_str = fields[11].strip() if len(fields) > 11 else ""
    balance = _parse_amount(balance_str)

    # 对方户名（index 12）
    counterparty = fields[12].strip() if len(fields) > 12 else ""

    # 对方账号（index 13）
    counterparty_acct = fields[13].strip() if len(fields) > 13 else ""

    # 构建描述
    description_parts = []
    if summary:
        description_parts.append(summary)
    if venue and venue not in ["手机银行", "网上银行", "批量业务"]:
        description_parts.append(venue)
    description = " - ".join(description_parts) if description_parts else ""

    # 构建商户名
    merchant = counterparty or venue or summary or "工商银行"

    # 复用平台识别逻辑
    from .utils import identify_platform_and_merchant
    platform, detected_merchant = identify_platform_and_merchant(
        counterparty or venue, summary, "icbc"
    )
    if platform not in ("线下", "工商银行"):
        merchant = detected_merchant or merchant

    # 手机银行/网上银行/批量业务 → 工商银行平台
    if venue in ("手机银行", "网上银行", "批量业务") and platform == "线下":
        platform = "工商银行"

    # 识别内部转账
    transfer_venues = ["支付宝-支付宝小荷包", "支付宝-小荷包", "支付宝-余额宝",
                       "财付通-零钱通", "财付通-零钱提现"]
    if any(tv in venue for tv in transfer_venues):
        txn_type = "transfer"
    elif summary in ("预约转账",) and counterparty and not venue:
        txn_type = "transfer"

    return {
        "order_no": f"ICBC_{txn_date.replace('-', '')}_{amount}_{hash(f'{txn_date}{amount}{counterparty}') % 10000:04d}",
        "transaction_time": txn_date,
        "merchant": merchant,
        "description": description,
        "amount": int(amount * 100),
        "type": txn_type,
        "platform": platform,
        "payment_method": f"工商银行信用卡({card_number[-4:]})" if card_number else "工商银行",
        "balance": int(balance * 100),
        "summary": summary,
        "venue": venue,
        "counterparty": counterparty,
        "counterparty_account": counterparty_acct,
    }
