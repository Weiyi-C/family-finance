"""支付方式匹配和账户类型建议"""

import re

# 支付方式 → 账户类型代码映射
PAYMENT_METHOD_TYPE_MAP = {
    "零钱": "wechat_balance",
    "零钱通": "wechat_lingqian",
    "余额": "alipay_balance",
    "余额宝": "alipay_yuebao",
    "花呗": "alipay_huabei",
    "借呗": "alipay_jiebei",
    # 银行卡关键词
    "工商银行": "bank_savings",
    "建设银行": "bank_savings",
    "农业银行": "bank_savings",
    "中国银行": "bank_savings",
    "交通银行": "bank_savings",
    "招商银行": "bank_savings",
    "浦发银行": "bank_savings",
    "民生银行": "bank_savings",
    "兴业银行": "bank_savings",
    "中信银行": "bank_savings",
    "光大银行": "bank_savings",
    "平安银行": "bank_savings",
    "邮储银行": "bank_savings",
    "广发银行": "bank_savings",
    "华夏银行": "bank_savings",
}


def match_payment_method_to_account(method: str, accounts: list) -> int | None:
    """将支付方式字符串匹配到用户已有的账户

    Args:
        method: 支付方式字符串（如"工商银行储蓄卡(0726)"）
        accounts: 用户的 PaymentAccount 列表

    Returns:
        匹配到的 account.id 或 None
    """
    method_clean = method.strip()

    # 1. 精确匹配
    for acc in accounts:
        if acc.name == method_clean:
            return acc.id

    # 2. 提取尾号匹配
    tail_match = re.search(r"[（(](\d{4})[）)]", method_clean)
    if tail_match:
        tail = tail_match.group(1)
        # 从方法名中提取银行名
        bank_part = re.sub(r"[（(]\d{4}[）)]", "", method_clean)
        bank_part = re.sub(r"储蓄卡|信用卡|借记卡", "", bank_part).strip()

        for acc in accounts:
            if acc.card_tail == tail:
                # 尾号匹配，再检查银行名
                if bank_part and acc.bank_name and bank_part in acc.bank_name:
                    return acc.id
                # 尾号相同且没有银行名冲突，也认为匹配
                if not bank_part or not acc.bank_name:
                    return acc.id

    # 3. 关键词匹配
    method_lower = method_clean.lower()
    for acc in accounts:
        acc_name = (acc.name or "").lower()
        # 零钱/零钱通
        if "零钱" in method_lower and "零钱" in acc_name:
            return acc.id
        # 银行名
        for bank_keyword in ["工商", "建设", "农业", "中国银行", "交通", "招商", "浦发", "民生", "兴业", "中信", "光大", "平安", "邮储", "广发", "华夏"]:
            if bank_keyword in method_lower and bank_keyword in acc_name:
                return acc.id

    return None


def suggest_account_type(method: str) -> dict:
    """根据支付方式字符串建议新建账户的类型信息

    Args:
        method: 支付方式字符串

    Returns:
        包含 type_code, name, bank_name, card_tail 等字段的字典
    """
    method_clean = method.strip()

    # 提取尾号
    tail_match = re.search(r"[（(](\d{4})[）)]", method_clean)
    card_tail = tail_match.group(1) if tail_match else None

    # 信用卡
    if "信用卡" in method_clean:
        bank_match = re.search(r"([\u4e00-\u9fa5]+银行)", method_clean)
        bank_name = bank_match.group(1) if bank_match else method_clean.replace("信用卡", "").strip()
        return {
            "type_code": "bank_credit",
            "name": method_clean,
            "bank_name": bank_name,
            "card_tail": card_tail,
            "group": "银行卡",
        }

    # 储蓄卡/借记卡
    if "储蓄卡" in method_clean or "借记卡" in method_clean:
        bank_match = re.search(r"([\u4e00-\u9fa5]+银行)", method_clean)
        bank_name = bank_match.group(1) if bank_match else method_clean.replace("储蓄卡", "").replace("借记卡", "").strip()
        return {
            "type_code": "bank_savings",
            "name": method_clean,
            "bank_name": bank_name,
            "card_tail": card_tail,
            "group": "银行卡",
        }

    # 零钱通
    if "零钱通" in method_clean:
        return {"type_code": "wechat_lingqian", "name": "零钱通", "group": "微信"}

    # 零钱
    if "零钱" in method_clean:
        return {"type_code": "wechat_balance", "name": "微信零钱", "group": "微信"}

    # 花呗
    if "花呗" in method_clean:
        return {"type_code": "alipay_huabei", "name": "花呗", "group": "支付宝"}

    # 余额宝
    if "余额宝" in method_clean:
        return {"type_code": "alipay_yuebao", "name": "余额宝", "group": "支付宝"}

    # 默认
    return {"type_code": "e_wallet", "name": method_clean, "group": "其他"}
