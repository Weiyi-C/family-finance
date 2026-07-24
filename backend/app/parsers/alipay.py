"""支付宝 CSV 账单解析器"""

import csv
from .utils import identify_platform_and_merchant


def parse_alipay_csv(content: str) -> tuple[list[dict], dict]:
    """解析支付宝 CSV 账单

    Returns:
        (items, meta) - items 为解析后的交易列表，meta 为元信息
    """
    lines = content.strip().split("\n")

    # 查找表头行（包含"交易"和"对方"或"金额"的行）
    header_idx = -1
    for i, line in enumerate(lines):
        if "交易" in line and ("对方" in line or "金额" in line):
            header_idx = i
            break
    if header_idx == -1:
        raise ValueError("无法识别支付宝账单格式")

    reader = csv.DictReader(lines[header_idx:])
    items = []
    methods = set()

    for row in reader:
        try:
            # 金额处理
            amount_str = row.get("金额", "0").replace(",", "").strip()
            if not amount_str:
                continue
            amount = float(amount_str)

            # 收/支方向
            direction = row.get("收/支", "").strip()
            if "不计收支" in direction:
                continue
            txn_type = "expense" if "支出" in direction else "income"

            # 状态过滤（跳过退款）
            status = row.get("交易状态", "").strip()
            if "退款" in status:
                continue

            # 支付方式
            payment_method = row.get("收/付款方式", "").strip()
            if not payment_method:
                # 尝试从"商品名称"推断
                desc = row.get("商品名称", "")
                if "花呗" in desc:
                    payment_method = "花呗"
                elif "余额宝" in desc:
                    payment_method = "余额宝"
                elif "借呗" in desc:
                    payment_method = "借呗"
            if payment_method:
                methods.add(payment_method)

            # 智能识别平台和商户
            counterparty = row.get("交易对方", "").strip()
            description = row.get("商品名称", "").strip()
            detected_platform, detected_merchant = identify_platform_and_merchant(
                counterparty, description, "alipay"
            )

            items.append({
                "order_no": row.get("交易号", "").strip(),
                "transaction_time": row.get("交易时间", "").strip(),
                "merchant": detected_merchant,
                "description": description,
                "amount": int(amount * 100),
                "type": txn_type,
                "platform": detected_platform,
                "platform_raw": row.get("收/付款方式", "").strip(),
                "payment_method": payment_method,
                "fund_status": row.get("资金状态", "").strip(),
                "txn_method": row.get("交易方式", "").strip(),
            })
        except Exception:
            continue

    meta = {
        "platform": "支付宝",
        "has_payment_method": len(methods) > 0,
        "detected_methods": list(methods),
    }
    return items, meta
