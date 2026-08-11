"""AI 后台分析服务 - 分析交易并生成建议"""

import structlog
from datetime import datetime, timedelta, timezone
from sqlalchemy import select, func, and_, cast, BigInteger
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.ai_suggestion import AISuggestion
from app.models.transaction import Transaction
from app.models.category import Category
from app.models.user import Family
from app.services.ai_service import get_ai_service

logger = structlog.get_logger()

ANALYSIS_LOOKBACK_DAYS = 30
MAX_TRANSACTIONS_PER_ANALYSIS = 200


class AIAnalyzer:
    """后台AI分析编排器"""

    def __init__(self, family_id: int, family_settings: dict):
        self.family_id = family_id
        self.family_settings = family_settings

    async def run_analysis(self, db: AsyncSession) -> list[dict]:
        """运行完整分析流程，返回生成的建议列表"""
        ai_service = get_ai_service(family_settings=self.family_settings)
        if not ai_service:
            logger.warning("ai_not_configured", family_id=self.family_id)
            return []

        suggestions = []

        # 1. 标签建议：无标签的交易
        tag_suggestions = await self._analyze_missing_tags(db, ai_service)
        suggestions.extend(tag_suggestions)

        # 2. 重复检测：最近交易中的疑似重复
        duplicate_suggestions = await self._analyze_duplicates(db, ai_service)
        suggestions.extend(duplicate_suggestions)

        # 3. 周期识别：重复出现的商户/金额模式
        periodic_suggestions = await self._analyze_periodic(db, ai_service)
        suggestions.extend(periodic_suggestions)

        # 4. 分类建议：未分类交易
        category_suggestions = await self._analyze_uncategorized(db, ai_service)
        suggestions.extend(category_suggestions)

        # 存入数据库
        stored = []
        for s in suggestions:
            record = AISuggestion(
                family_id=self.family_id,
                type=s["type"],
                suggestion=s["suggestion"],
                reason=s.get("reason"),
                transaction_ids=s.get("transaction_ids"),
            )
            db.add(record)
            stored.append(s)

        await db.commit()
        logger.info("ai_analysis_complete", family_id=self.family_id, count=len(stored))
        return stored

    async def _get_recent_transactions(self, db: AsyncSession, limit: int = MAX_TRANSACTIONS_PER_ANALYSIS):
        """获取最近的交易记录（仅debit侧，即用户视角）"""
        cutoff = datetime.now(timezone.utc) - timedelta(days=ANALYSIS_LOOKBACK_DAYS)
        result = await db.execute(
            select(Transaction).where(
                Transaction.family_id == self.family_id,
                Transaction.is_deleted == False,
                Transaction.entry_side == "debit",
                Transaction.transaction_time >= cutoff,
            ).order_by(Transaction.transaction_time.desc()).limit(limit)
        )
        return list(result.scalars().all())

    async def _analyze_missing_tags(self, db: AsyncSession, ai_service) -> list[dict]:
        """分析缺少标签的交易"""
        txns = await self._get_recent_transactions(db)
        # 筛选无标签的交易
        from app.models.transaction_tag import TransactionTag
        tagged_result = await db.execute(
            select(TransactionTag.transaction_id).where(
                TransactionTag.transaction_id.in_([t.id for t in txns])
            )
        )
        tagged_ids = set(tagged_result.scalars().all())
        untagged = [t for t in txns if t.id not in tagged_ids and t.type in ("expense", "income")]

        if not untagged:
            return []

        # 取前50条发给AI
        batch = untagged[:50]
        txn_data = []
        for t in batch:
            txn_data.append({
                "id": t.id,
                "merchant": t.merchant_name or "",
                "description": t.description or "",
                "amount": abs(t.amount) / 100,
                "type": t.type,
            })

        categories = await self._get_categories(db)
        prompt = self._build_tag_prompt(txn_data, categories)

        try:
            response = await ai_service._call_llm(prompt, max_tokens=3000)
            if not response:
                return []
            return self._parse_tag_response(response, batch)
        except Exception as e:
            logger.error("ai_tag_analysis_error", error=str(e))
            return []

    async def _analyze_duplicates(self, db: AsyncSession, ai_service) -> list[dict]:
        """检测疑似重复交易（本地规则 + AI确认）"""
        txns = await self._get_recent_transactions(db, 200)
        if len(txns) < 2:
            return []

        # 本地规则：同日+同商户+同金额 → 疑似重复
        seen = {}
        duplicate_groups = []
        for t in txns:
            key = (
                t.transaction_time.strftime("%Y-%m-%d") if t.transaction_time else "",
                (t.merchant_name or "").strip(),
                t.amount,
            )
            if key in seen:
                duplicate_groups.append([seen[key].id, t.id])
            else:
                seen[key] = t

        if not duplicate_groups:
            return []

        # 发给AI确认
        txn_map = {t.id: t for t in txns}
        confirm_data = []
        for group in duplicate_groups[:10]:
            items = []
            for txn_id in group:
                t = txn_map.get(txn_id)
                if t:
                    items.append({
                        "id": t.id,
                        "time": t.transaction_time.strftime("%Y-%m-%d %H:%M") if t.transaction_time else "",
                        "merchant": t.merchant_name or "",
                        "description": t.description or "",
                        "amount": abs(t.amount) / 100,
                    })
            confirm_data.append({"group": items})

        prompt = self._build_duplicate_prompt(confirm_data)
        try:
            response = await ai_service._call_llm(prompt, max_tokens=2000)
            if not response:
                # AI不可用时仍返回本地检测结果
                return [
                    {
                        "type": "duplicate",
                        "transaction_ids": group,
                        "suggestion": {"duplicate_group": group},
                        "reason": "同日同商户同金额",
                    }
                    for group in duplicate_groups[:10]
                ]
            return self._parse_duplicate_response(response, duplicate_groups)
        except Exception as e:
            logger.error("ai_duplicate_analysis_error", error=str(e))
            return [
                {
                    "type": "duplicate",
                    "transaction_ids": group,
                    "suggestion": {"duplicate_group": group},
                    "reason": "同日同商户同金额",
                }
                for group in duplicate_groups[:10]
            ]

    async def _analyze_periodic(self, db: AsyncSession, ai_service) -> list[dict]:
        """识别周期性交易模式"""
        txns = await self._get_recent_transactions(db, 200)
        if not txns:
            return []

        # 按商户分组统计
        merchant_groups = {}
        for t in txns:
            if t.type != "expense":
                continue
            key = (t.merchant_name or "").strip()
            if not key or len(key) < 2:
                continue
            if key not in merchant_groups:
                merchant_groups[key] = []
            merchant_groups[key].append(t)

        # 找出出现3次以上的商户
        candidates = {k: v for k, v in merchant_groups.items() if len(v) >= 3}
        if not candidates:
            return []

        # 发给AI分析周期
        analysis_data = []
        for merchant, txn_list in list(candidates.items())[:10]:
            analysis_data.append({
                "merchant": merchant,
                "count": len(txn_list),
                "amounts": [abs(t.amount) / 100 for t in txn_list[:5]],
                "dates": [t.transaction_time.strftime("%Y-%m-%d") for t in txn_list[:5] if t.transaction_time],
            })

        prompt = self._build_periodic_prompt(analysis_data)
        try:
            response = await ai_service._call_llm(prompt, max_tokens=2000)
            if not response:
                return []
            return self._parse_periodic_response(response, candidates)
        except Exception as e:
            logger.error("ai_periodic_analysis_error", error=str(e))
            return []

    async def _analyze_uncategorized(self, db: AsyncSession, ai_service) -> list[dict]:
        """分析未分类交易"""
        txns = await self._get_recent_transactions(db)
        uncategorized = [t for t in txns if not t.category_id and t.type in ("expense", "income")]

        if not uncategorized:
            return []

        batch = uncategorized[:50]
        txn_data = []
        for t in batch:
            txn_data.append({
                "id": t.id,
                "merchant": t.merchant_name or "",
                "description": t.description or "",
                "amount": abs(t.amount) / 100,
                "type": t.type,
            })

        categories = await self._get_categories(db)
        prompt = self._build_category_prompt(txn_data, categories)

        try:
            response = await ai_service._call_llm(prompt, max_tokens=3000)
            if not response:
                return []
            return self._parse_category_response(response, batch)
        except Exception as e:
            logger.error("ai_category_analysis_error", error=str(e))
            return []

    async def _get_categories(self, db: AsyncSession) -> list[dict]:
        result = await db.execute(
            select(Category).where(
                (Category.family_id == self.family_id) | (Category.family_id.is_(None)),
                Category.is_active == True,
            )
        )
        return [{"id": c.id, "name": c.name, "level": c.level} for c in result.scalars()]

    # === Prompt 构建 ===

    def _build_tag_prompt(self, transactions: list[dict], categories: list[dict]) -> str:
        cat_list = "\n".join(f"- {c['name']}" for c in categories[:50])
        txn_list = "\n".join(
            f"{i+1}. 商户:{t['merchant']}, 描述:{t['description']}, 金额:{t['amount']:.2f}元, 类型:{t['type']}"
            for i, t in enumerate(transactions)
        )
        return f"""请为以下交易推荐合适的标签（1-3个标签/条）。

可选分类参考：
{cat_list}

交易记录：
{txn_list}

请返回 JSON 格式：
{{"results": [{{"txn_index": 0, "tags": ["标签1", "标签2"], "reason": "理由"}}]}}

标签应简洁实用，如：停车、外卖、打车、网购、会员续费、工资等。
只返回 JSON，不要其他内容。"""

    def _build_duplicate_prompt(self, groups: list[dict]) -> str:
        group_text = ""
        for i, g in enumerate(groups):
            items = "\n    ".join(
                f"ID:{it['id']} 时间:{it['time']} 商户:{it['merchant']} 描述:{it['description']} 金额:{it['amount']:.2f}"
                for it in g["group"]
            )
            group_text += f"\n组{i+1}:\n    {items}\n"

        return f"""请判断以下疑似重复交易组是否真的是重复记录。

{group_text}

返回 JSON 格式：
{{"results": [{{"group_index": 0, "is_duplicate": true, "reason": "理由"}}]}}

只返回 JSON，不要其他内容。"""

    def _build_periodic_prompt(self, data: list[dict]) -> str:
        text = "\n".join(
            f"商户:{d['merchant']}, 出现{d['count']}次, 金额:{d['amounts']}, 日期:{d['dates']}"
            for d in data
        )
        return f"""请分析以下商户的消费模式，识别是否有周期性消费（如月度会员、定期缴费等）。

{text}

返回 JSON 格式：
{{"results": [{{"merchant": "商户名", "is_periodic": true, "interval": "monthly/weekly/yearly", "suggested_name": "建议名称", "reason": "理由"}}]}}

只返回 JSON，不要其他内容。"""

    def _build_category_prompt(self, transactions: list[dict], categories: list[dict]) -> str:
        cat_list = "\n".join(f"- {c['name']}" for c in categories[:50])
        txn_list = "\n".join(
            f"{i+1}. 商户:{t['merchant']}, 描述:{t['description']}, 金额:{t['amount']:.2f}元, 类型:{t['type']}"
            for i, t in enumerate(transactions)
        )
        return f"""请为以下未分类交易选择最合适的分类。

可选分类：
{cat_list}

交易记录：
{txn_list}

返回 JSON 格式：
{{"results": [{{"txn_index": 0, "category_name": "分类名称", "confidence": 0.9, "reason": "理由"}}]}}

只返回 JSON，不要其他内容。"""

    # === 响应解析 ===

    def _parse_tag_response(self, response: str, transactions: list) -> list[dict]:
        import json
        try:
            json_str = response
            if "```json" in response:
                json_str = response.split("```json")[1].split("```")[0]
            elif "```" in response:
                json_str = response.split("```")[1].split("```")[0]
            result = json.loads(json_str.strip())
            suggestions = []
            for item in result.get("results", []):
                idx = item.get("txn_index", 0)
                if 0 <= idx < len(transactions) and item.get("tags"):
                    suggestions.append({
                        "type": "tag",
                        "transaction_ids": [transactions[idx].id],
                        "suggestion": {"tags": item["tags"]},
                        "reason": item.get("reason", ""),
                    })
            return suggestions
        except Exception as e:
            logger.error("parse_tag_response_error", error=str(e))
            return []

    def _parse_duplicate_response(self, response: str, groups: list) -> list[dict]:
        import json
        try:
            json_str = response
            if "```json" in response:
                json_str = response.split("```json")[1].split("```")[0]
            elif "```" in response:
                json_str = response.split("```")[1].split("```")[0]
            result = json.loads(json_str.strip())
            suggestions = []
            for item in result.get("results", []):
                idx = item.get("group_index", 0)
                if 0 <= idx < len(groups) and item.get("is_duplicate"):
                    suggestions.append({
                        "type": "duplicate",
                        "transaction_ids": groups[idx],
                        "suggestion": {"duplicate_group": groups[idx]},
                        "reason": item.get("reason", ""),
                    })
            return suggestions
        except Exception as e:
            logger.error("parse_duplicate_response_error", error=str(e))
            return []

    def _parse_periodic_response(self, response: str, candidates: dict) -> list[dict]:
        import json
        try:
            json_str = response
            if "```json" in response:
                json_str = response.split("```json")[1].split("```")[0]
            elif "```" in response:
                json_str = response.split("```")[1].split("```")[0]
            result = json.loads(json_str.strip())
            suggestions = []
            for item in result.get("results", []):
                if item.get("is_periodic"):
                    merchant = item.get("merchant", "")
                    txn_ids = [t.id for t in candidates.get(merchant, [])]
                    suggestions.append({
                        "type": "periodic",
                        "transaction_ids": txn_ids,
                        "suggestion": {
                            "merchant": merchant,
                            "interval": item.get("interval", "monthly"),
                            "suggested_name": item.get("suggested_name", merchant),
                        },
                        "reason": item.get("reason", ""),
                    })
            return suggestions
        except Exception as e:
            logger.error("parse_periodic_response_error", error=str(e))
            return []

    def _parse_category_response(self, response: str, transactions: list) -> list[dict]:
        import json
        try:
            json_str = response
            if "```json" in response:
                json_str = response.split("```json")[1].split("```")[0]
            elif "```" in response:
                json_str = response.split("```")[1].split("```")[0]
            result = json.loads(json_str.strip())
            suggestions = []
            for item in result.get("results", []):
                idx = item.get("txn_index", 0)
                if 0 <= idx < len(transactions) and item.get("category_name"):
                    suggestions.append({
                        "type": "category",
                        "transaction_ids": [transactions[idx].id],
                        "suggestion": {
                            "category_name": item["category_name"],
                            "confidence": item.get("confidence", 0.8),
                        },
                        "reason": item.get("reason", ""),
                    })
            return suggestions
        except Exception as e:
            logger.error("parse_category_response_error", error=str(e))
            return []
