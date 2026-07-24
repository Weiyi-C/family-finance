"""平台和商户智能识别工具"""

# 已知电商平台集合
KNOWN_PLATFORMS = {
    "淘宝", "天猫", "京东", "拼多多", "美团", "饿了么",
    "抖音", "小红书", "闲鱼", "唯品会", "得物",
    "携程", "去哪儿", "飞猪", "滴滴", "大众点评",
}


def identify_platform_and_merchant(
    counterparty: str, description: str, source: str
) -> tuple[str, str]:
    """识别平台和真实商户名

    Args:
        counterparty: 交易对方（原始）
        description: 商品描述
        source: 来源（alipay/wechat）

    Returns:
        (platform, merchant)
    """
    # 检查"交易对方"是否是已知平台
    for platform in KNOWN_PLATFORMS:
        if platform in counterparty:
            merchant = counterparty

            # 尝试从描述中提取真实商户
            if description:
                # 模式1: "商户名(分店)外卖订单"
                if "外卖订单" in description:
                    merchant = description.replace("外卖订单", "").strip()
                # 模式2: "商户名-商品描述"
                elif "-" in description:
                    parts = description.split("-", 1)
                    if 2 < len(parts[0]) < 20:
                        merchant = parts[0].strip()
                # 模式3: "商户名(分店)"
                elif "(" in description and ")" in description:
                    match = description[: description.index(")") + 1]
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
