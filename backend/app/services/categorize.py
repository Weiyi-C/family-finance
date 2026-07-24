"""自动分类和标签服务"""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

# ===================== 自动分类规则 =====================
# 按优先级排序，先匹配先生效
AUTO_CATEGORY_RULES = [
    # -- 转账/红包（最高优先级） --
    {"keywords": ["红包"], "category_expense": "红包", "category_income": "红包收入", "tags": ["红包"]},
    {"keywords": ["转账", "还款", "代付", "亲属卡"], "category_expense": "转账", "category_income": "转账收入", "tags": ["转账"]},

    # -- 餐饮 --
    {"keywords": ["外卖", "美团外卖", "饿了么"], "category_expense": "餐饮", "tags": ["外卖"]},
    {"keywords": ["麦当劳", "肯德基", "KFC", "星巴克", "瑞幸", "喜茶", "奈雪", "蜜雪冰城", "必胜客", "汉堡王", "海底捞", "西贝"], "category_expense": "餐饮", "tags": ["餐饮"]},
    {"keywords": ["餐厅", "饭店", "食堂", "小吃", "烧烤", "火锅", "面馆", "早餐", "午餐", "晚餐", "下午茶", "咖啡", "奶茶", "蛋糕", "面包"], "category_expense": "餐饮", "tags": ["餐饮"]},
    {"keywords": ["美团", "饿了么"], "category_expense": "餐饮", "tags": ["外卖"]},

    # -- 食材采购 --
    {"keywords": ["超市", "便利店", "菜市场", "水果", "盒马", "永辉", "大润发", "沃尔玛", "家乐福", "山姆", "Costco", "开市客"], "category_expense": "食材采购", "tags": ["超市"]},

    # -- 交通出行 --
    {"keywords": ["滴滴", "打车", "出租车", "曹操出行", "T3出行", "高德打车"], "category_expense": "交通出行", "tags": ["打车"]},
    {"keywords": ["停车", "加油", "充电桩", "中石油", "中石化", "ETC"], "category_expense": "交通出行", "tags": ["交通"]},
    {"keywords": ["地铁", "公交", "一卡通", "交通卡"], "category_expense": "交通出行", "tags": ["交通"]},

    # -- 差旅 --
    {"keywords": ["火车", "高铁", "12306", "机票", "飞机", "携程", "去哪儿", "飞猪", "同程", "酒店", "民宿", "Airbnb"], "category_expense": "差旅", "tags": ["出差"]},

    # -- 购物 --
    {"keywords": ["淘宝", "天猫", "京东", "拼多多", "抖音商城", "抖音小店", "唯品会", "得物", "闲鱼"], "category_expense": "购物", "tags": ["网购"]},
    {"keywords": ["Apple", "苹果", "华为", "小米", "OPPO", "VIVO", "三星"], "category_expense": "购物", "tags": ["购物"]},

    # -- 休闲娱乐 --
    {"keywords": ["电影", "影院", "万达影城", "猫眼", "淘票票"], "category_expense": "休闲娱乐", "tags": ["娱乐"]},
    {"keywords": ["游戏", "Steam", "腾讯游戏", "网易游戏", "App Store", "Apple Music", "爱奇艺", "优酷", "腾讯视频", "B站", "bilibili", "Netflix", "Spotify"], "category_expense": "休闲娱乐", "tags": ["订阅"]},
    {"keywords": ["KTV", "酒吧", "网吧", "剧本杀", "密室"], "category_expense": "休闲娱乐", "tags": ["娱乐"]},

    # -- 居住 --
    {"keywords": ["电费", "水费", "燃气", "暖气", "物业", "房租", "房贷", "按揭"], "category_expense": "住房", "tags": ["居住"]},
    {"keywords": ["装修", "家具", "家电", "宜家"], "category_expense": "住房", "tags": ["购物"]},

    # -- 通讯 --
    {"keywords": ["话费", "流量", "宽带", "中国移动", "中国联通", "中国电信"], "category_expense": "通讯", "tags": ["通讯"]},

    # -- 医疗健康 --
    {"keywords": ["医院", "药店", "诊所", "口腔", "牙科", "体检", "药房", "大参林", "老百姓大药房"], "category_expense": "医疗健康", "tags": ["医疗"]},

    # -- 教育 --
    {"keywords": ["学费", "培训", "课程", "书店", "图书", "当当", "得到", "知乎", "网课"], "category_expense": "教育学习", "tags": ["教育"]},

    # -- 服饰美容 --
    {"keywords": ["理发", "美甲", "化妆品", "护肤", "ZARA", "H&M", "优衣库", "耐克", "阿迪"], "category_expense": "服饰美容", "tags": ["美容"]},

    # -- 孝敬家长 --
    {"keywords": ["孝敬", "爸妈", "父母", "长辈"], "category_expense": "孝敬家长", "tags": ["孝敬"]},

    # -- 保险 --
    {"keywords": ["保险", "社保", "公积金", "平安保险", "中国人寿"], "category_expense": "保险", "tags": ["保险"]},

    # -- 投资 --
    {"keywords": ["基金", "股票", "理财", "定期", "利息"], "category_expense": "投资亏损", "category_income": "投资收益", "tags": ["投资"]},
]

# 平台 → 默认分类映射（关键词匹配失败时使用）
PLATFORM_CATEGORY_MAP = {
    "美团": "餐饮", "饿了么": "餐饮", "大众点评": "餐饮",
    "淘宝": "购物", "天猫": "购物", "京东": "购物", "拼多多": "购物",
    "抖音": "购物", "闲鱼": "购物",
    "携程": "差旅", "去哪儿": "差旅", "飞猪": "差旅",
    "滴滴": "交通出行",
}

# 支付方式 → 默认分类映射
PAYMENT_METHOD_CATEGORY_MAP = {
    "花呗": "购物",
    "余额宝": None,
    "零钱通": None,
}

# 平台 → 默认标签
PLATFORM_TAG_MAP = {
    "淘宝": "网购", "天猫": "网购", "京东": "网购", "拼多多": "网购", "抖音": "网购",
    "美团": "外卖", "饿了么": "外卖",
    "携程": "出差", "去哪儿": "出差",
}


def auto_categorize(
    merchant: str,
    description: str,
    txn_type: str = "expense",
    platform: str = "",
    payment_method: str = "",
) -> tuple[str | None, list[str]]:
    """自动分类 + 自动标签

    Args:
        merchant: 商户名
        description: 商品描述
        txn_type: 交易类型（expense/income）
        platform: 平台名
        payment_method: 支付方式

    Returns:
        (分类名, 标签列表)
    """
    combined = f"{merchant} {description}".lower()
    tags: list[str] = []

    # 1. 关键词规则匹配
    for rule in AUTO_CATEGORY_RULES:
        for keyword in rule["keywords"]:
            if keyword.lower() in combined:
                cat = (
                    rule.get("category_income")
                    if txn_type == "income" and "category_income" in rule
                    else rule["category_expense"]
                )
                tags.extend(rule.get("tags", []))
                return cat, tags

    # 2. 平台分类回退
    if platform:
        cat = PLATFORM_CATEGORY_MAP.get(platform)
        if cat:
            tag = PLATFORM_TAG_MAP.get(platform)
            if tag:
                tags.append(tag)
            return cat, tags

    # 3. 支付方式回退
    if payment_method:
        cat = PAYMENT_METHOD_CATEGORY_MAP.get(payment_method)
        if cat:
            return cat, tags

    return None, tags


async def ai_suggest_category(
    db: AsyncSession, user, merchant: str, description: str
) -> str | None:
    """调用 AI 规则引擎推荐分类（规则匹配失败时的回退）

    Args:
        db: 数据库会话
        user: 当前用户
        merchant: 商户名
        description: 商品描述

    Returns:
        分类名或 None
    """
    from app.api.ai import CATEGORY_KEYWORDS

    combined = f"{merchant} {description}".lower()
    for cat_name, keywords in CATEGORY_KEYWORDS.items():
        for keyword in keywords:
            if keyword in combined:
                return cat_name
    return None


async def auto_assign_tags(
    db: AsyncSession, family_id: int, txn_id: int, tag_names: list[str]
) -> None:
    """自动创建并分配标签到交易

    Args:
        db: 数据库会话
        family_id: 家庭 ID
        txn_id: 交易 ID（entry_id）
        tag_names: 标签名称列表
    """
    from app.models.tag import Tag
    from app.models.transaction_tag import TransactionTag

    for name in tag_names:
        if not name:
            continue

        # 查找或创建标签
        result = await db.execute(
            select(Tag).where(Tag.family_id == family_id, Tag.name == name)
        )
        tag = result.scalar_one_or_none()
        if not tag:
            tag = Tag(family_id=family_id, name=name)
            db.add(tag)
            await db.flush()

        # 创建关联（忽略重复）
        existing = await db.execute(
            select(TransactionTag).where(
                TransactionTag.transaction_id == txn_id,
                TransactionTag.tag_id == tag.id,
            )
        )
        if not existing.scalar_one_or_none():
            db.add(TransactionTag(transaction_id=txn_id, tag_id=tag.id))
