"""自动分类和标签服务"""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

# ===================== 自动分类规则 =====================
# 按优先级排序，先匹配先生效
# 注意：分类名必须与数据库 seed 数据一致
# 设计原则：一条规则匹配后立即返回，不会有多标签
AUTO_CATEGORY_RULES = [
    # -- 收入类（高优先级，仅匹配收入交易） --
    {"keywords": ["工资", "薪资", "薪酬", "月薪", "绩效", "加班费", "补贴", "津贴"], "category_income": "工资薪酬", "tags": ["工资"]},
    {"keywords": ["奖金", "年终奖", "中奖", "绩效奖"], "category_income": "奖金中奖", "tags": ["奖金"]},
    {"keywords": ["利息", "利息收入", "活期利息", "定期利息"], "category_income": "其他收入", "tags": ["利息"]},
    {"keywords": ["公积金", "住房公积金"], "category_income": "其他收入", "tags": ["公积金"]},
    {"keywords": ["租金", "房租收入", "租金收入"], "category_income": "租金收入", "tags": ["租金"]},
    {"keywords": ["退款", "退保", "退货", "退款收入"], "category_income": "退款收入", "tags": ["退款"]},
    {"keywords": ["理财收益", "基金收益", "股票收益", "投资收益", "分红"], "category_income": "投资收益", "tags": ["投资"]},
    {"keywords": ["他行汇入", "转入", "汇入"], "category_income": "转账收入", "tags": ["转账"]},

    # -- 内部转账（识别为转账，不计入收支） --
    {"keywords": ["小荷包", "零钱通", "余额宝", "自动攒", "自动转入", "转出到", "转入到"], "category_expense": "转账", "tags": []},

    # -- 红包 --
    {"keywords": ["红包", "微信红包", "支付宝红包"], "category_expense": "红包", "category_income": "红包收入", "tags": ["红包"]},

    # -- 保险（高优先级，避免被其他规则误匹配） --
    {"keywords": ["保费", "保险", "社保", "车险", "人寿", "财产险"], "category_expense": "保险", "tags": ["保险"]},

    # -- 餐饮 --
    {"keywords": ["外卖", "美团外卖", "饿了么"], "category_expense": "餐饮", "tags": ["外卖"]},
    {"keywords": ["麦当劳", "肯德基", "KFC", "星巴克", "瑞幸", "喜茶", "奈雪", "蜜雪冰城", "必胜客", "汉堡王", "海底捞", "西贝", "呷哺呷哺", "真功夫", "永和大王", "吉野家"], "category_expense": "餐饮", "tags": ["餐饮"]},
    {"keywords": ["餐厅", "饭店", "食堂", "小吃", "烧烤", "火锅", "面馆", "咖啡", "奶茶", "蛋糕", "面包", "米粉", "麻辣烫", "饺子", "包子", "快餐", "便当", "寿司", "披萨"], "category_expense": "餐饮", "tags": ["餐饮"]},

    # -- 食材采购 --
    {"keywords": ["超市", "便利店", "菜市场", "盒马", "永辉", "大润发", "沃尔玛", "家乐福", "山姆", "七鲜", "物美", "华润万家", "联华"], "category_expense": "食材采购", "tags": ["超市"]},

    # -- 交通出行 --
    {"keywords": ["滴滴", "打车", "出租车", "曹操出行", "T3出行", "高德打车", "花小猪", "首汽约车"], "category_expense": "打车", "tags": ["打车"]},
    {"keywords": ["停车", "停车费", "停车缴费", "停车场", "停车服务"], "category_expense": "停车费", "tags": ["停车"]},
    {"keywords": ["加油", "充电桩", "中石油", "中石化", "壳牌", "加油站"], "category_expense": "自驾加油", "tags": ["加油"]},
    {"keywords": ["ETC", "过路费", "高速费", "通行费"], "category_expense": "过路费", "tags": ["高速"]},
    {"keywords": ["地铁", "公交", "一卡通", "交通卡", "公共交通", "轨道交通"], "category_expense": "公共交通", "tags": ["交通"]},

    # -- 差旅 --
    {"keywords": ["火车", "高铁", "12306", "动车", "城际"], "category_expense": "火车高铁", "tags": ["出差"]},
    {"keywords": ["机票", "飞机", "携程", "去哪儿", "飞猪", "同程", "航班", "航空"], "category_expense": "差旅", "tags": ["出差"]},
    {"keywords": ["酒店", "民宿", "Airbnb", "宾馆", "旅馆", "住宿"], "category_expense": "住宿", "tags": ["出差"]},

    # -- 购物 --
    {"keywords": ["淘宝", "天猫", "京东", "拼多多", "抖音商城", "唯品会", "得物", "闲鱼", "小红书", "苏宁", "国美", "当当"], "category_expense": "日用品", "tags": ["网购"]},

    # -- 休闲娱乐 --
    {"keywords": ["电影", "影院", "猫眼", "淘票票", "万达影城", "横店影城"], "category_expense": "影视", "tags": ["娱乐"]},
    {"keywords": ["爱奇艺", "优酷", "腾讯视频", "B站", "bilibili", "Netflix", "Spotify", "Apple Music", "芒果TV", "搜狐视频", "乐视"], "category_expense": "影视", "tags": ["订阅"]},
    {"keywords": ["游戏", "Steam", "腾讯游戏", "网易游戏", "手游", "网游", "PlayStation", "Xbox", "Nintendo"], "category_expense": "游戏", "tags": ["游戏"]},
    {"keywords": ["KTV", "酒吧", "网吧", "剧本杀", "密室", "桌游", "棋牌"], "category_expense": "休闲活动", "tags": ["娱乐"]},

    # -- 居住 --
    {"keywords": ["房租", "房贷", "按揭", "租金", "月供"], "category_expense": "房租/房贷", "tags": ["居住"]},
    {"keywords": ["电费", "水费", "燃气", "暖气", "水电费", "燃气费"], "category_expense": "水电燃气", "tags": ["居住"]},
    {"keywords": ["物业", "物业费", "物业管理费"], "category_expense": "物业费", "tags": ["居住"]},
    {"keywords": ["装修", "家具", "宜家", "家居", "家电", "建材"], "category_expense": "装修", "tags": ["家居"]},

    # -- 通讯 --
    {"keywords": ["话费", "流量", "中国移动", "中国联通", "中国电信", "充值", "手机充值", "流量包"], "category_expense": "通讯网络", "tags": ["通讯"]},
    {"keywords": ["宽带", "网络费", "网费"], "category_expense": "通讯网络", "tags": ["通讯"]},

    # -- 医疗健康 --
    {"keywords": ["医院", "诊所", "就医", "挂号", "门诊", "住院", "手术"], "category_expense": "就医", "tags": ["医疗"]},
    {"keywords": ["药店", "药房", "大参林", "老百姓大药房", "海王星辰", "同仁堂"], "category_expense": "药品", "tags": ["医疗"]},
    {"keywords": ["体检", "疫苗", "体检中心", "防疫"], "category_expense": "疫苗体检", "tags": ["医疗"]},
    {"keywords": ["口腔", "牙科", "牙医", "口腔医院"], "category_expense": "口腔", "tags": ["医疗"]},

    # -- 教育 --
    {"keywords": ["学费", "培训", "课程", "网课", "辅导", "补习", "补习班"], "category_expense": "辅导培训", "tags": ["教育"]},
    {"keywords": ["书店", "图书", "当当", "教材", "教辅", "文具", "文具店"], "category_expense": "教材教辅", "tags": ["教育"]},

    # -- 服饰美妆 --
    {"keywords": ["理发", "美甲", "美发", "发型", "造型"], "category_expense": "美容美发", "tags": ["美容"]},
    {"keywords": ["化妆品", "护肤", "美妆", "口红", "面膜", "护肤品"], "category_expense": "美妆护肤", "tags": ["美容"]},
    {"keywords": ["ZARA", "H&M", "优衣库", "耐克", "阿迪", "Nike", "Adidas", "李宁", "安踏", "特步"], "category_expense": "服饰美妆", "tags": ["购物"]},

    # -- 母婴亲子 --
    {"keywords": ["奶粉", "纸尿裤", "婴儿", "母婴", "儿童", "玩具", "童装"], "category_expense": "母婴亲子", "tags": ["母婴"]},

    # -- 宠物 --
    {"keywords": ["宠物", "猫粮", "狗粮", "宠物医院", "宠物店"], "category_expense": "宠物", "tags": ["宠物"]},

    # -- 金融理财（支出） --
    {"keywords": ["手续费", "银行费用", "年费", "账户管理费"], "category_expense": "银行费用", "tags": ["手续费"]},
    {"keywords": ["购汇", "换汇", "外汇", "汇率"], "category_expense": "汇率换汇", "tags": ["换汇"]},
    {"keywords": ["贷款", "还款", "还贷", "还信用卡"], "category_expense": "转账", "tags": ["还款"]},

    # -- 工作办公 --
    {"keywords": ["办公用品", "文具", "打印", "复印", "快递", "顺丰", "圆通", "中通", "韵达"], "category_expense": "办公用品", "tags": ["办公"]},

    # -- 数码科技 --
    {"keywords": ["手机", "电脑", "笔记本", "平板", "耳机", "充电器", "数据线"], "category_expense": "数码科技", "tags": ["数码"]},

    # -- 其他 --
    {"keywords": ["捐款", "慈善", "公益", "捐赠"], "category_expense": "慈善捐赠", "tags": ["公益"]},
    {"keywords": ["罚款", "罚单", "违章"], "category_expense": "罚款", "tags": ["罚款"]},
]

# 平台 → 默认分类映射（关键词匹配失败时使用）
PLATFORM_CATEGORY_MAP = {
    "美团": "餐饮", "饿了么": "餐饮", "大众点评": "餐饮",
    "淘宝": "日用品", "天猫": "日用品", "京东": "日用品", "拼多多": "日用品",
    "抖音": "日用品", "闲鱼": "日用品", "小红书": "日用品", "唯品会": "日用品", "得物": "日用品",
    "携程": "差旅", "去哪儿": "差旅", "飞猪": "差旅",
    "滴滴": "打车",
}

# 支付方式 → 默认分类映射
PAYMENT_METHOD_CATEGORY_MAP = {
    "花呗": "日用品",
    "余额宝": None,
    "零钱通": None,
}

# 平台 → 默认标签
PLATFORM_TAG_MAP = {
    "淘宝": "网购", "天猫": "网购", "京东": "网购", "拼多多": "网购",
    "抖音": "网购", "闲鱼": "网购", "小红书": "网购", "唯品会": "网购", "得物": "网购",
    "美团": "外卖", "饿了么": "外卖",
    "携程": "出差", "去哪儿": "出差", "飞猪": "出差",
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
                # 根据交易类型选择分类
                if txn_type == "income":
                    cat = rule.get("category_income")
                    if not cat:
                        continue  # 只有支出分类的规则，不匹配收入交易
                else:
                    cat = rule.get("category_expense")
                    if not cat:
                        continue  # 只有收入分类的规则，不匹配支出交易

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
    db: AsyncSession, user, merchant: str, description: str,
    amount: float = 0, txn_type: str = "expense"
) -> str | None:
    """调用 AI 推荐分类

    优先使用大模型 API，回退到关键词规则
    """
    # 1. 尝试使用大模型 API
    if user and hasattr(user, 'family_id') and user.family_id:
        from app.services.ai_service import get_ai_service

        # 从家庭设置中获取 AI 配置
        family_settings = {}
        if hasattr(user, 'family') and user.family:
            family_settings = user.family.settings or {}

        ai_service = get_ai_service(family_settings=family_settings, user_settings=user.settings)
        if ai_service:
            # 获取分类列表
            from app.models.category import Category
            cats_result = await db.execute(
                select(Category).where(
                    (Category.family_id == user.family_id) | (Category.family_id.is_(None))
                )
            )
            categories = [
                {"id": c.id, "name": c.name, "level": c.level}
                for c in cats_result.scalars()
            ]

            # 调用 AI 分类
            result = await ai_service.categorize_transaction(
                merchant=merchant,
                description=description,
                amount=amount / 100,  # 转换为元
                txn_type=txn_type,
                categories=categories,
            )

            if result and result.get("category_name"):
                return result["category_name"]

    # 2. 回退到关键词规则
    combined = f"{merchant} {description}".lower()

    AI_RULES = {
        # 支出分类
        "餐饮": ["外卖", "餐厅", "饭店", "食堂", "小吃", "烧烤", "火锅", "面馆", "咖啡", "奶茶", "蛋糕"],
        "食材采购": ["超市", "便利店", "菜市场", "水果", "生鲜"],
        "打车": ["滴滴", "打车", "出租车", "网约车"],
        "停车费": ["停车", "停车场"],
        "自驾加油": ["加油", "加油站", "充电桩"],
        "公共交通": ["地铁", "公交", "公共交通"],
        "火车高铁": ["火车", "高铁", "动车"],
        "差旅": ["机票", "飞机", "航班"],
        "住宿": ["酒店", "宾馆", "民宿"],
        "日用品": ["购物", "商场", "百货"],
        "影视": ["电影", "影院", "视频", "视频会员"],
        "游戏": ["游戏", "手游", "网游"],
        "房租/房贷": ["房租", "房贷", "租金"],
        "水电燃气": ["电费", "水费", "燃气", "暖气"],
        "物业费": ["物业", "物业费"],
        "通讯网络": ["话费", "流量", "宽带", "充值"],
        "就医": ["医院", "诊所", "看病"],
        "药品": ["药店", "药房", "买药"],
        "辅导培训": ["培训", "课程", "辅导"],
        "保险": ["保险", "保费", "社保"],
        "银行费用": ["手续费", "银行费用", "年费"],
        # 收入分类
        "工资薪酬": ["工资", "薪资", "薪酬", "月薪"],
        "奖金中奖": ["奖金", "年终奖", "中奖"],
        "投资收益": ["理财", "基金", "股票", "收益"],
        "红包收入": ["红包"],
        "转账收入": ["转账", "汇款"],
    }

    for cat_name, keywords in AI_RULES.items():
        for keyword in keywords:
            if keyword in combined:
                return cat_name

    return None


async def auto_assign_tags(
    db: AsyncSession, family_id: int, txn_id: int, tag_names: list[str]
) -> None:
    """自动创建并分配标签到交易"""
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


async def auto_categorize_with_db(
    db: AsyncSession,
    family_id: int,
    merchant: str,
    description: str,
    txn_type: str = "expense",
    platform: str = "",
    payment_method: str = "",
) -> tuple[str | None, list[str]]:
    """自动分类（优先数据库规则，兜底代码规则）

    Args:
        db: 数据库会话
        family_id: 家庭ID
        merchant: 商户名
        description: 商品描述
        txn_type: 交易类型（expense/income）
        platform: 平台名
        payment_method: 支付方式

    Returns:
        (分类名, 标签列表)
    """
    from app.models.rule import AutomationRule
    from sqlalchemy import or_

    combined = f"{merchant} {description}".lower()

    # 1. 查询数据库规则（优先用户私有，其次系统级）
    result = await db.execute(
        select(AutomationRule).where(
            AutomationRule.is_active == True,
            or_(AutomationRule.family_id == family_id, AutomationRule.family_id.is_(None)),
            AutomationRule.stage == "classify",
        ).order_by(
            AutomationRule.priority.desc(),
            AutomationRule.family_id.nulls_last(),  # 用户私有优先
        )
    )
    rules = result.scalars().all()

    for rule in rules:
        conditions = rule.conditions or {}
        actions = rule.actions or {}
        keywords = conditions.get("keywords", [])
        if not keywords:
            continue
        # 检查是否有关键词匹配
        if any(kw.lower() in combined for kw in keywords):
            category_name = actions.get("category_name")
            tags = actions.get("tags", [])
            if category_name:
                # 检查交易类型是否匹配
                from app.models.category import Category
                cat_result = await db.execute(
                    select(Category).where(
                        (Category.family_id == family_id) | (Category.family_id.is_(None)),
                        Category.name == category_name,
                    ).limit(1)
                )
                cat = cat_result.scalar_one_or_none()
                if cat:
                    # 收入分类不匹配支出交易，反之亦然
                    if txn_type == "expense" and cat.type == "income":
                        continue
                    if txn_type == "income" and cat.type == "expense":
                        continue
                rule.hit_count += 1
                return category_name, tags

    # 2. 兜底：代码硬编码规则
    return auto_categorize(merchant, description, txn_type, platform, payment_method)
