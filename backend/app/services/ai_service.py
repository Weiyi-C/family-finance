"""AI 大模型服务 - 支持多种大模型 API"""

import httpx
import json
from typing import Optional

# 支持的大模型配置
AI_PROVIDERS = {
    "openai": {
        "name": "OpenAI (GPT)",
        "base_url": "https://api.openai.com/v1",
        "models": ["gpt-3.5-turbo", "gpt-4", "gpt-4-turbo", "gpt-4o", "gpt-4o-mini"],
        "default_model": "gpt-4o-mini",
    },
    "dashscope": {
        "name": "通义千问",
        "base_url": "https://dashscope.aliyuncs.com/compatible-mode/v1",
        "models": ["qwen-turbo", "qwen-plus", "qwen-max", "qwen-long"],
        "default_model": "qwen-turbo",
    },
    "deepseek": {
        "name": "DeepSeek",
        "base_url": "https://api.deepseek.com/v1",
        "models": ["deepseek-chat", "deepseek-coder"],
        "default_model": "deepseek-chat",
    },
    "mimo": {
        "name": "小米 MiMo",
        "base_url": "https://token-plan-cn.xiaomimimo.com/v1",
        "models": ["mimo-v2.5-pro", "mimo-v2.5", "mimo-v2.5-asr", "mimo-v2.5-tts-voiceclone", "mimo-v2.5-tts-voicedesign", "mimo-v2.5-tts"],
        "default_model": "mimo-v2.5-pro",
    },
    "custom": {
        "name": "自定义 (OpenAI 兼容)",
        "base_url": "",
        "models": [],
        "default_model": "",
    },
}


class AIService:
    """AI 大模型服务"""

    def __init__(self, provider: str, api_key: str, base_url: str = "", model: str = ""):
        self.provider = provider
        self.api_key = api_key
        self.base_url = base_url or AI_PROVIDERS.get(provider, {}).get("base_url", "")
        self.model = model or AI_PROVIDERS.get(provider, {}).get("default_model", "")

    async def categorize_transaction(
        self,
        merchant: str,
        description: str,
        amount: float,
        txn_type: str,
        categories: list[dict],
    ) -> Optional[dict]:
        """使用 AI 对交易进行分类

        Args:
            merchant: 商户名
            description: 商品描述
            amount: 金额（元）
            txn_type: 交易类型（expense/income）
            categories: 可选的分类列表 [{id, name, level}]

        Returns:
            {category_id, category_name, confidence, reason} 或 None
        """
        # 构建分类列表字符串
        cat_list = "\n".join([
            f"- {c['name']} (ID: {c['id']}, Level: {c['level']})"
            for c in categories[:50]  # 限制数量避免 prompt 过长
        ])

        # 构建 prompt
        prompt = f"""你是一个智能记账助手。请根据以下交易信息，从提供的分类列表中选择最合适的分类。

交易信息：
- 商户：{merchant}
- 描述：{description}
- 金额：{amount:.2f}元
- 类型：{'收入' if txn_type == 'income' else '支出'}

可选分类：
{cat_list}

请返回 JSON 格式：
{{
    "category_id": 选择的分类ID,
    "category_name": "选择的分类名称",
    "confidence": 置信度(0-1),
    "reason": "选择原因(简短)"
}}

只返回 JSON，不要其他内容。"""

        try:
            response = await self._call_llm(prompt)
            if response:
                # 解析 JSON 响应
                # 尝试提取 JSON 部分
                json_str = response
                if "```json" in response:
                    json_str = response.split("```json")[1].split("```")[0]
                elif "```" in response:
                    json_str = response.split("```")[1].split("```")[0]

                result = json.loads(json_str.strip())
                return {
                    "category_id": result.get("category_id"),
                    "category_name": result.get("category_name"),
                    "confidence": result.get("confidence", 0.8),
                    "reason": result.get("reason", ""),
                }
        except Exception as e:
            print(f"AI categorization error: {e}")

        return None

    async def _call_llm(self, prompt: str, system_prompt: str = "", max_tokens: int = 200) -> Optional[str]:
        """调用大模型 API"""
        if not self.api_key or not self.base_url:
            return None

        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }

        messages = []
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        else:
            messages.append({"role": "system", "content": "你是一个智能记账助手，擅长处理财务数据。"})
        messages.append({"role": "user", "content": prompt})

        payload = {
            "model": self.model,
            "messages": messages,
            "temperature": 0.3,
            "max_tokens": max_tokens,
        }

        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                response = await client.post(
                    f"{self.base_url}/chat/completions",
                    headers=headers,
                    json=payload,
                )
                response.raise_for_status()
                result = response.json()
                return result["choices"][0]["message"]["content"]
        except Exception as e:
            print(f"LLM API error: {e}")
            return None

    async def _call_llm_vision(self, prompt: str, image_base64: str, max_tokens: int = 2000) -> Optional[str]:
        """调用支持视觉的大模型 API（用于图片识别）"""
        if not self.api_key or not self.base_url:
            return None

        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }

        payload = {
            "model": self.model,
            "messages": [
                {
                    "role": "system",
                    "content": "你是一个智能记账助手，擅长从图片中识别和提取账单信息。请仔细识别图片中的每一笔交易记录。"
                },
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt},
                        {
                            "type": "image_url",
                            "image_url": {"url": f"data:image/jpeg;base64,{image_base64}"}
                        }
                    ]
                }
            ],
            "temperature": 0.2,
            "max_tokens": max_tokens,
        }

        try:
            async with httpx.AsyncClient(timeout=120.0) as client:
                response = await client.post(
                    f"{self.base_url}/chat/completions",
                    headers=headers,
                    json=payload,
                )
                response.raise_for_status()
                result = response.json()
                return result["choices"][0]["message"]["content"]
        except Exception as e:
            print(f"LLM Vision API error: {e}")
            return None

    async def categorize_batch(
        self,
        transactions: list[dict],
        categories: list[dict],
    ) -> Optional[list[dict]]:
        """批量使用 AI 对交易进行分类

        Args:
            transactions: 交易列表 [{merchant, description, amount, type}]
            categories: 可选的分类列表 [{id, name, level}]

        Returns:
            [{category_name, confidence}] 或 None
        """
        # 构建分类列表字符串
        cat_list = "\n".join([
            f"- {c['name']} (ID: {c['id']})"
            for c in categories[:50]
        ])

        # 构建交易列表字符串
        txn_list = "\n".join([
            f"{i+1}. 商户:{t.get('merchant','')}, 描述:{t.get('description','')}, 金额:{t.get('amount',0):.2f}元, 类型:{'收入' if t.get('type')=='income' else '支出'}"
            for i, t in enumerate(transactions[:50])  # 限制50条
        ])

        prompt = f"""请为以下交易记录选择最合适的分类。

可选分类：
{cat_list}

交易记录：
{txn_list}

请返回 JSON 格式，包含每条交易的分类：
{{
    "results": [
        {{"category_name": "分类名称", "confidence": 0.9}},
        ...
    ]
}}

只返回 JSON，不要其他内容。"""

        try:
            response = await self._call_llm(prompt, max_tokens=2000)
            if response:
                json_str = response
                if "```json" in response:
                    json_str = response.split("```json")[1].split("```")[0]
                elif "```" in response:
                    json_str = response.split("```")[1].split("```")[0]

                result = json.loads(json_str.strip())
                return result.get("results", [])
        except Exception as e:
            print(f"AI batch categorization error: {e}")

        return None
        """使用 AI 解析账单文件

        Args:
            file_content: 文件内容（文本）
            file_type: 文件类型 (csv/txt)

        Returns:
            解析后的交易列表或 None
        """
        prompt = f"""请分析以下账单文件内容，提取所有交易记录。

文件类型：{file_type}
文件内容（前3000字符）：
{file_content[:3000]}

请返回 JSON 格式的交易列表，每条记录包含：
{{
    "transactions": [
        {{
            "transaction_time": "交易时间 (YYYY-MM-DD HH:MM:SS)",
            "merchant": "商户名",
            "description": "商品/描述",
            "amount": 金额(正数, 单位元),
            "type": "expense 或 income",
            "payment_method": "支付方式（如有）",
            "category_hint": "分类提示（如有）"
        }}
    ]
}}

只返回 JSON，不要其他内容。"""

        try:
            response = await self._call_llm(prompt, max_tokens=4000)
            if response:
                json_str = response
                if "```json" in response:
                    json_str = response.split("```json")[1].split("```")[0]
                elif "```" in response:
                    json_str = response.split("```")[1].split("```")[0]

                result = json.loads(json_str.strip())
                return result.get("transactions", [])
        except Exception as e:
            print(f"AI parse bill error: {e}")

        return None

    async def parse_bill_image(self, image_base64: str) -> Optional[list[dict]]:
        """使用 AI 从图片中识别账单

        Args:
            image_base64: 图片的 base64 编码

        Returns:
            解析后的交易列表或 None
        """
        prompt = """请仔细查看这张账单/交易记录图片，提取所有可见的交易记录。

常见的账单类型包括：
- 银行卡交易明细
- 支付宝/微信账单截图
- 购物小票
- 发票
- 转账记录截图

请返回 JSON 格式的交易列表：
{
    "transactions": [
        {
            "transaction_time": "交易时间 (尽可能精确，格式 YYYY-MM-DD HH:MM:SS)",
            "merchant": "商户名/收款方",
            "description": "商品/描述/备注",
            "amount": 金额(正数, 单位元),
            "type": "expense 或 income",
            "payment_method": "支付方式（如有）",
            "category_hint": "分类提示（如：餐饮、交通、购物等）"
        }
    ]
}

注意事项：
- 如果看不清某些字段，可以留空或使用 null
- 金额必须是数字，不要包含货币符号
- 如果是多张图片或多页，只处理当前可见的内容
- 只返回 JSON，不要其他内容"""

        try:
            response = await self._call_llm_vision(prompt, image_base64, max_tokens=4000)
            if response:
                json_str = response
                if "```json" in response:
                    json_str = response.split("```json")[1].split("```")[0]
                elif "```" in response:
                    json_str = response.split("```")[1].split("```")[0]

                result = json.loads(json_str.strip())
                return result.get("transactions", [])
        except Exception as e:
            print(f"AI parse bill image error: {e}")

        return None


def get_ai_service(user_settings: dict = None, family_settings: dict = None) -> Optional[AIService]:
    """获取 AI 服务实例

    优先从家庭设置读取，回退到用户设置
    """
    # 优先使用家庭设置
    settings = family_settings or user_settings or {}
    ai_config = settings.get("ai", {})

    if not ai_config.get("enabled"):
        return None

    provider = ai_config.get("provider", "")
    api_key = ai_config.get("api_key", "")

    if not provider or not api_key:
        return None

    return AIService(
        provider=provider,
        api_key=api_key,
        base_url=ai_config.get("base_url", ""),
        model=ai_config.get("model", ""),
    )
