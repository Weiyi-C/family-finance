import structlog
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.database import get_db
from app.models.category import Category
from app.models.transaction import Transaction
from app.models.user import User

logger = structlog.get_logger()
router = APIRouter(tags=["AI记账"])

# 简单的关键词规则引擎（可扩展为真正的AI模型）
CATEGORY_KEYWORDS = {
    # 餐饮
    "餐饮": ["外卖", "美团", "饿了么", "餐厅", "饭店", "食堂", "麦当劳", "肯德基", "星巴克", "瑞幸", "咖啡", "奶茶", "火锅", "烧烤"],
    "食材采购": ["超市", "便利店", "菜市场", "水果", "生鲜", "盒马", "永辉"],
    # 交通
    "交通出行": ["滴滴", "打车", "出租车", "停车", "加油", "地铁", "公交", "高铁", "火车", "机票", "飞机"],
    # 购物
    "购物": ["淘宝", "京东", "拼多多", "天猫", "苏宁", "唯品会"],
    # 娱乐
    "休闲娱乐": ["电影", "游戏", "KTV", "酒吧", "网吧", "剧本杀"],
    # 生活
    "住房": ["房租", "物业", "水电", "燃气", "暖气"],
    "通讯": ["话费", "流量", "宽带", "中国移动", "中国联通", "中国电信"],
    # 医疗
    "医疗健康": ["医院", "药店", "诊所", "体检", "牙科"],
    # 教育
    "教育培训": ["学费", "培训", "课程", "书店", "文具"],
    # 转账
    "转账": ["转账", "红包", "还款"],
}

MERCHANT_PATTERNS = {
    "肯德基": {"category": "餐饮", "merchant": "肯德基"},
    "KFC": {"category": "餐饮", "merchant": "肯德基"},
    "麦当劳": {"category": "餐饮", "merchant": "麦当劳"},
    "星巴克": {"category": "餐饮", "merchant": "星巴克"},
    "瑞幸": {"category": "餐饮", "merchant": "瑞幸咖啡"},
    "滴滴": {"category": "交通出行", "merchant": "滴滴出行"},
    "美团": {"category": "购物", "merchant": "美团"},
    "淘宝": {"category": "购物", "merchant": "淘宝"},
    "京东": {"category": "购物", "merchant": "京东"},
}


@router.post("/api/ai/parse")
async def parse_transaction(
    body: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """AI解析交易文本

    输入: {"text": "今天在肯德基吃了午饭花了35块"}
    输出: {
        "amount": 3500,
        "merchant": "肯德基",
        "category": "餐饮",
        "type": "expense",
        "description": "午饭"
    }
    """
    text_input = body.get("text", "")
    if not text_input:
        raise HTTPException(status_code=400, detail="请输入文本")

    # 提取金额
    import re
    amount_match = re.search(r'(\d+\.?\d*)\s*[元块]', text_input)
    amount = 0
    if amount_match:
        amount = int(float(amount_match.group(1)) * 100)

    # 识别商户
    merchant = None
    category = None
    for pattern, info in MERCHANT_PATTERNS.items():
        if pattern in text_input:
            merchant = info["merchant"]
            category = info["category"]
            break

    # 如果没有匹配到商户，尝试关键词分类
    if not category:
        for cat, keywords in CATEGORY_KEYWORDS.items():
            for keyword in keywords:
                if keyword in text_input:
                    category = cat
                    break
            if category:
                break

    # 判断收/支
    txn_type = "expense"
    income_keywords = ["工资", "收入", "奖金", "红包", "退款", "报销"]
    for keyword in income_keywords:
        if keyword in text_input:
            txn_type = "income"
            break

    # 查找分类ID
    category_id = None
    if category:
        cat_result = await db.execute(
            select(Category).where(
                Category.name == category,
                (Category.family_id == current_user.family_id) | (Category.family_id.is_(None)),
                Category.level == 1,
            ).limit(1)
        )
        cat_obj = cat_result.scalar_one_or_none()
        if cat_obj:
            category_id = cat_obj.id

    # 提取描述（去掉金额和商户后的文本）
    description = text_input
    if amount_match:
        description = description.replace(amount_match.group(0), "")
    if merchant:
        description = description.replace(merchant, "")
    description = description.strip()
    if not description:
        description = text_input[:50]

    return {
        "amount": amount,
        "merchant": merchant,
        "category": category,
        "category_id": category_id,
        "type": txn_type,
        "description": description,
        "confidence": 0.8 if merchant else 0.5,
    }


@router.post("/api/ai/suggest-category")
async def suggest_category(
    body: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """根据商户名/描述推荐分类"""
    merchant = body.get("merchant", "")
    description = body.get("description", "")
    combined = f"{merchant} {description}"

    suggestions = []
    for cat, keywords in CATEGORY_KEYWORDS.items():
        for keyword in keywords:
            if keyword in combined:
                # 查找分类ID
                cat_result = await db.execute(
                    select(Category).where(
                        Category.name == cat,
                        (Category.family_id == current_user.family_id) | (Category.family_id.is_(None)),
                        Category.level == 1,
                    ).limit(1)
                )
                cat_obj = cat_result.scalar_one_or_none()
                if cat_obj:
                    suggestions.append({
                        "category_id": cat_obj.id,
                        "category_name": cat,
                        "confidence": 0.9 if keyword == merchant else 0.7,
                    })
                break

    return {"suggestions": suggestions[:5]}
