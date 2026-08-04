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
            # 清理列名空格
            cleaned_row = {k.strip(): v for k, v in row.items() if k}

            # 金额处理（支持多种列名格式）
            amount_str = "0"
            for key in ["金额", "金额（元）", "金额(元)"]:
                if key in cleaned_row:
                    amount_str = cleaned_row[key]
                    break
            amount_str = amount_str.replace(",", "").strip()
            if not amount_str:
                continue
            amount = float(amount_str)

            # 收/支方向
            direction = ""
            for key in ["收/支", "收/支"]:
                if key in cleaned_row:
                    direction = cleaned_row[key]
                    break
            direction = direction.strip()
            if "不计收支" in direction:
                continue
            txn_type = "expense" if "支出" in direction else "income"

            # 状态过滤（跳过退款）
            status = ""
            for key in ["交易状态", "当前状态"]:
                if key in cleaned_row:
                    status = cleaned_row[key]
                    break
            status = status.strip()
            if "退款" in status:
                continue

            # 支付方式
            payment_method = ""
            for key in ["收/付款方式", "支付方式"]:
                if key in cleaned_row:
                    payment_method = cleaned_row[key]
                    break
            payment_method = payment_method.strip()
            if not payment_method:
                desc = cleaned_row.get("商品名称", "") or cleaned_row.get("商品", "")
                if "花呗" in desc:
                    payment_method = "花呗"
                elif "余额宝" in desc:
                    payment_method = "余额宝"
                elif "借呗" in desc:
                    payment_method = "借呗"
            if payment_method:
                methods.add(payment_method)

            # 智能识别平台和商户
            counterparty = (cleaned_row.get("交易对方", "") or "").strip()
            description = (cleaned_row.get("商品名称", "") or cleaned_row.get("商品", "") or "").strip()
            platform_raw = (cleaned_row.get("交易来源地", "") or "").strip()

            # 优先使用"交易来源地"字段判断平台
            detected_platform = "支付宝"
            detected_merchant = counterparty

            if platform_raw:
                # 交易来源地直接标明了平台
                for known in ["淘宝", "天猫", "京东", "拼多多", "美团", "饿了么", "抖音", "小红书", "闲鱼", "唯品会", "得物"]:
                    if known in platform_raw:
                        detected_platform = known
                        break

                # 尝试从描述中提取真实商户
                if description and detected_platform != "支付宝":
                    if "-" in description:
                        parts = description.split("-", 1)
                        if 2 < len(parts[0]) < 20:
                            detected_merchant = parts[0].strip()
                    elif "(" in description and ")" in description:
                        match = description[: description.index(")") + 1]
                        if len(match) > 2:
                            detected_merchant = match.strip()
                    else:
                        detected_merchant = counterparty
            else:
                # 没有交易来源地，用通用识别逻辑
                detected_platform, detected_merchant = identify_platform_and_merchant(
                    counterparty, description, "alipay"
                )

            # 交易时间
            txn_time = ""
            for key in ["交易创建时间", "交易时间", "付款时间"]:
                if key in cleaned_row and cleaned_row[key].strip():
                    txn_time = cleaned_row[key].strip()
                    break

            # 交易号
            order_no = (cleaned_row.get("交易号", "") or "").strip()

            items.append({
                "order_no": order_no,
                "transaction_time": txn_time,
                "merchant": detected_merchant,
                "description": description,
                "amount": int(amount * 100),
                "type": txn_type,
                "platform": detected_platform,
                "platform_raw": (cleaned_row.get("交易来源地", "") or "").strip(),
                "payment_method": payment_method,
                "fund_status": (cleaned_row.get("资金状态", "") or "").strip(),
                "txn_method": (cleaned_row.get("类型", "") or "").strip(),
            })
        except Exception:
            continue

    meta = {
        "platform": "支付宝",
        "has_payment_method": len(methods) > 0,
        "detected_methods": list(methods),
    }
    return items, meta
