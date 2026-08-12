"""建设银行信用卡 CSV 账单解析器"""

import csv
import re
from io import StringIO

from .utils import identify_platform_and_merchant


def parse_ccb_credit_csv(content: str) -> tuple[list[dict], dict]:
    """解析建设银行信用卡 CSV 明细

    格式特点：
    - 前13行为标题/元信息，第14行为表头
    - 数据行之间有空行
    - 卡号以单引号前缀
    - 表头：交易日, 入账日, 信用卡卡号, 类型, 入账币种, 入账金额, 交易描述

    Returns:
        (items, meta)
    """
    lines = content.strip().split("\n")

    # 提取卡号（从元信息或数据行）
    card_number = ""
    card_match = re.search(r"信用卡卡号[：:]\s*'?(\d{4,})", content)
    if card_match:
        card_number = card_match.group(1)

    # 查找表头行（包含"交易日"和"入账金额"的行）
    header_idx = -1
    for i, line in enumerate(lines):
        if "交易日" in line and "入账金额" in line:
            header_idx = i
            break
    if header_idx == -1:
        raise ValueError("无法识别建设银行信用卡账单格式")

    # 解析表头
    reader = csv.reader(StringIO(lines[header_idx]))
    headers = [h.strip() for h in next(reader)]

    items = []
    methods = set()

    for line in lines[header_idx + 1:]:
        line = line.strip()
        if not line:
            continue

        # 解析字段
        reader = csv.reader(StringIO(line))
        fields = [f.strip() for f in next(reader)]

        if len(fields) < 6:
            continue

        try:
            # 构建 row dict
            row = {}
            for j, field in enumerate(fields):
                if j < len(headers):
                    row[headers[j]] = field

            # 交易日
            txn_date = row.get("交易日", "").strip()
            if not txn_date or not re.match(r"\d{8}", txn_date):
                continue
            txn_date = f"{txn_date[:4]}-{txn_date[4:6]}-{txn_date[6:8]}"

            # 信用卡卡号（从数据行提取）
            card_raw = row.get("信用卡卡号", "").strip().lstrip("'")
            if card_raw and not card_number:
                card_number = card_raw
            current_card = card_raw or card_number

            # 类型
            txn_type_raw = row.get("类型", "").strip()

            # 入账金额
            amount_str = row.get("入账金额", "0").replace(",", "").strip()
            if not amount_str:
                continue
            amount = float(amount_str)
            if amount == 0:
                continue

            # 交易描述
            description = row.get("交易描述", "").strip()

            # 识别 transfer 类型
            if txn_type_raw in ("还款", "转入"):
                txn_type = "transfer"
            elif "还款" in description:
                txn_type = "transfer"
            else:
                txn_type = "expense"

            # 平台和商户识别
            # 建行信用卡的交易描述格式：支付宝-特约商户、20260729高速通行费四川成德南金堂
            platform = "建设银行"
            merchant = description
            # 检查描述是否以已知平台开头
            for known in ["支付宝", "微信", "财付通", "京东", "美团", "抖音", "淘宝", "天猫", "拼多多"]:
                if description.startswith(known):
                    platform = known
                    # 提取商户名（去掉平台前缀）
                    merchant = description[len(known):].lstrip("-").strip() or description
                    break
            if platform == "建设银行":
                # 没有匹配到已知平台，使用通用识别
                platform, merchant = identify_platform_and_merchant(
                    description, description, "ccb"
                )

            # 支付方式
            payment_method = f"建设银行信用卡({current_card[-4:]})" if current_card else "建设银行信用卡"
            methods.add(payment_method)

            items.append({
                "order_no": f"CCB_{txn_date.replace('-', '')}_{int(amount * 100)}_{hash(f'{txn_date}{amount}{description}') % 10000:04d}",
                "transaction_time": txn_date,
                "merchant": merchant,
                "description": description,
                "amount": int(amount * 100),
                "type": txn_type,
                "platform": platform,
                "payment_method": payment_method,
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
