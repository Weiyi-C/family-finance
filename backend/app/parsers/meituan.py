"""美团账单 CSV 解析器"""

import csv
import re
from io import StringIO

from .utils import identify_platform_and_merchant, KNOWN_PLATFORMS


def parse_meituan_csv(content: str) -> tuple[list[dict], dict]:
    """解析美团账单 CSV

    格式特点：
    - 前19行为标题/统计/免责声明，第20行为表头
    - 金额带 ¥ 前缀
    - 表头：交易创建时间, 交易成功时间, 交易类型, 订单标题, 收/支, 支付方式, 订单金额, 实付金额, 交易单号, 商家单号, 备注

    Returns:
        (items, meta)
    """
    lines = content.strip().split("\n")

    # 查找表头行（包含"交易创建时间"和"实付金额"的行）
    header_idx = -1
    for i, line in enumerate(lines):
        if "交易创建时间" in line and "实付金额" in line:
            header_idx = i
            break
    if header_idx == -1:
        raise ValueError("无法识别美团账单格式")

    # 解析表头
    reader = csv.reader(StringIO(lines[header_idx]))
    headers = [h.strip() for h in next(reader)]

    items = []
    methods = set()

    for line in lines[header_idx + 1:]:
        line = line.strip()
        if not line:
            continue

        reader = csv.reader(StringIO(line))
        fields = [f.strip() for f in next(reader)]

        if len(fields) < 6:
            continue

        try:
            row = {}
            for j, field in enumerate(fields):
                if j < len(headers):
                    row[headers[j]] = field

            # 金额（实付金额，去掉 ¥ 前缀）
            amount_str = row.get("实付金额", "0").replace("¥", "").replace(",", "").strip()
            if not amount_str:
                continue
            amount = float(amount_str)
            if amount == 0:
                continue

            # 收/支方向
            direction = row.get("收/支", "").strip()

            # 交易类型
            txn_type_raw = row.get("交易类型", "").strip()
            order_title = row.get("订单标题", "").strip()

            # 识别 transfer 类型（还款）
            if txn_type_raw == "还款" or "还款" in order_title:
                txn_type = "transfer"
            elif "支出" in direction:
                txn_type = "expense"
            elif "收入" in direction:
                txn_type = "income"
            else:
                continue

            # 交易时间（使用交易成功时间）
            txn_time = row.get("交易成功时间", "").strip()
            if not txn_time:
                txn_time = row.get("交易创建时间", "").strip()

            # 交易单号
            order_no = row.get("交易单号", "").strip()

            # 支付方式
            payment_method = row.get("支付方式", "").strip()
            if payment_method:
                methods.add(payment_method)

            # 商户名：从订单标题中提取
            # 订单标题格式："姜胖胖韩式自助烤肉..." 或 "【美团月付】主动还款..."
            merchant = order_title
            # 去掉【】包裹的前缀
            merchant = re.sub(r"^【[^】]+】", "", merchant).strip()
            # 截取到第一个特殊字符
            if len(merchant) > 30:
                merchant = merchant[:30]

            # 平台识别：检查订单标题中是否包含已知平台
            platform = "美团"
            for known in KNOWN_PLATFORMS:
                if known in order_title and known != "美团":
                    platform = known
                    break

            items.append({
                "order_no": order_no,
                "transaction_time": txn_time,
                "merchant": merchant,
                "description": order_title,
                "amount": int(amount * 100),
                "type": txn_type,
                "platform": platform,
                "payment_method": payment_method,
            })
        except Exception:
            continue

    meta = {
        "platform": "美团",
        "has_payment_method": True,
        "detected_methods": list(methods),
    }
    return items, meta
