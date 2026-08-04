"""工商银行 PDF 账单解析器"""

import re
from io import BytesIO


def parse_icbc_pdf(content_bytes: bytes) -> tuple[list[dict], dict]:
    """解析工商银行 PDF 借记账户历史明细"""
    from PyPDF2 import PdfReader

    reader = PdfReader(BytesIO(content_bytes))
    text = ""
    for page in reader.pages:
        text += page.extract_text() + "\n"

    if not text.strip():
        raise ValueError("无法提取 PDF 文本内容")

    return _parse_icbc_text(text)


def _parse_icbc_text(text: str) -> tuple[list[dict], dict]:
    """解析工行 PDF 文本内容"""
    # 提取卡号
    card_match = re.search(r"卡号\s*(\d{16,19})", text)
    card_number = card_match.group(1) if card_match else ""

    # 提取户名
    name_match = re.search(r"户名[：:]\s*([^\s]+)", text)
    account_name = name_match.group(1) if name_match else ""

    # 提取起止日期
    date_range_match = re.search(r"起止日期[：:]\s*(\d{4}-\d{2}-\d{2})\s*[-—]\s*(\d{4}-\d{2}-\d{2})", text)
    start_date = date_range_match.group(1) if date_range_match else ""
    end_date = date_range_match.group(2) if date_range_match else ""

    # 使用正则匹配每条交易记录
    # 格式：日期\n时间+账号 储种 序号 币种 钞汇 摘要 地区 金额 余额 对方户名 对方账号 渠道
    items = []

    # 匹配模式：日期行 + 下一行包含交易详情
    lines = text.split("\n")
    i = 0
    while i < len(lines):
        line = lines[i].strip()

        # 检测日期行
        date_match = re.match(r"^(\d{4}-\d{2}-\d{2})$", line)
        if date_match:
            txn_date = date_match.group(1)

            # 下一行应该是交易详情
            if i + 1 < len(lines):
                detail_line = lines[i + 1].strip()

                # 尝试解析详情行
                txn = _parse_detail_line(txn_line=detail_line, txn_date=txn_date)
                if txn:
                    items.append(txn)
                    i += 2
                    continue

        i += 1

    # 转换为标准格式
    result_items = []
    for txn in items:
        amount = txn["amount"]
        txn_type = "expense" if amount < 0 else "income"
        abs_amount = abs(amount)

        description_parts = []
        if txn["summary"]:
            description_parts.append(txn["summary"])
        if txn["counterparty"]:
            description_parts.append(txn["counterparty"])
        description = " - ".join(description_parts) if description_parts else ""

        # 复用平台识别逻辑
        from .utils import identify_platform_and_merchant
        platform, detected_merchant = identify_platform_and_merchant(
            txn["counterparty"] or "", txn["summary"] or "", "icbc"
        )
        merchant = detected_merchant or txn["counterparty"] or txn["summary"] or "工商银行"

        result_items.append({
            "order_no": f"ICBC_{txn['date'].replace('-', '')}_{abs_amount}_{len(result_items)}",
            "transaction_time": f"{txn['date']} {txn['time']}" if txn['time'] else txn['date'],
            "merchant": merchant,
            "description": description,
            "amount": int(abs_amount * 100),
            "type": txn_type,
            "platform": platform,
            "payment_method": f"工商银行储蓄卡({card_number[-4:]})" if card_number else "工商银行",
            "balance": int(txn["balance"] * 100),
            "summary": txn["summary"],
            "channel": txn["channel"],
        })

    meta = {
        "platform": "工商银行",
        "card_number": card_number,
        "account_name": account_name,
        "start_date": start_date,
        "end_date": end_date,
        "has_payment_method": True,
        "detected_methods": [f"工商银行储蓄卡({card_number[-4:]})"] if card_number else [],
    }

    return result_items, meta


def _parse_detail_line(txn_line: str, txn_date: str) -> dict | None:
    """解析交易详情行

    格式示例：
    07:21:224402001201103036031 活期 00000 人民币 钞预约转账 4402 -200.00 6,543.59 郑维一 6217003800052086844 其他
    """
    if not txn_line:
        return None

    # 提取时间（格式：07:21:22）
    time_match = re.search(r"(\d{2}:\d{2}:\d{2})", txn_line)
    txn_time = time_match.group(1) if time_match else ""

    # 提取账号（15-19位数字）
    account_match = re.search(r"(\d{15,19})", txn_line)
    account = account_match.group(1) if account_match else ""

    # 提取摘要（中文关键词）
    summary = ""
    summary_patterns = [
        "预约转账", "消费", "工资", "还款", "银联入账", "无卡支付",
        "数字人民币", "销户", "理财", "转账", "兑出", "兑入"
    ]
    for pattern in summary_patterns:
        if pattern in txn_line:
            summary = pattern
            break

    # 提取金额（格式：-200.00 或 +2,000.00）
    amount_match = re.search(r"([+-]?[\d,]+\.\d{2})", txn_line)
    if not amount_match:
        return None
    amount_str = amount_match.group(1).replace(",", "")
    amount = float(amount_str)

    # 提取余额（金额后面的那个数字）
    # 找到金额后，继续搜索下一个数字
    amount_end = amount_match.end()
    balance_match = re.search(r"([\d,]+\.\d{2})", txn_line[amount_end:])
    balance = float(balance_match.group(1).replace(",", "")) if balance_match else 0

    # 提取对方户名（金额和对方账号之间的中文）
    # 对方账号格式：6217****8411 或 2088****1911
    counterparty_acct_match = re.search(r"(\d{4}\*{4}\d{4})", txn_line)
    counterparty_account = counterparty_acct_match.group(1) if counterparty_acct_match else ""

    # 提取对方户名（在金额和对方账号之间的中文）
    counterparty = ""
    if balance_match and counterparty_acct_match:
        between = txn_line[amount_end + balance_match.end():counterparty_acct_match.start()]
        # 清理噪音字符
        between = re.sub(r"[0-9,.\s]", "", between).strip()
        if between and re.search(r"[\u4e00-\u9fa5]", between):
            counterparty = between

    # 提取渠道
    channel = ""
    channel_keywords = ["其他", "快捷支付", "网上银行", "手机银行", "ATM", "柜台"]
    for kw in channel_keywords:
        if kw in txn_line:
            channel = kw
            break

    return {
        "date": txn_date,
        "time": txn_time,
        "account": account,
        "summary": summary,
        "amount": amount,
        "balance": balance,
        "counterparty": counterparty,
        "counterparty_account": counterparty_account,
        "channel": channel,
    }
