"""汇率自动更新服务"""

import httpx
import structlog
from datetime import date
from sqlalchemy import select, and_
from sqlalchemy.dialects.postgresql import insert as pg_insert

from app.models.monitoring import ExchangeRate
from app.database import async_session

logger = structlog.get_logger()

# 免费汇率API（无需API Key）
EXCHANGE_RATE_API_URL = "https://open.er-api.com/v6/latest/CNY"

# 主要货币列表
MAJOR_CURRENCIES = [
    "USD", "EUR", "JPY", "GBP", "HKD", "AUD", "CAD", "SGD", 
    "CHF", "SEK", "NOK", "DKK", "NZD", "KRW", "THB", "MYR",
    "IDR", "PHP", "VND", "INR", "RUB", "BRL", "ZAR", "MXN",
    "AED", "SAR", "QAR", "KWD", "BHD", "OMR",
]


async def fetch_exchange_rates() -> dict[str, float]:
    """从API获取汇率数据"""
    async with httpx.AsyncClient(timeout=30.0) as client:
        try:
            response = await client.get(EXCHANGE_RATE_API_URL)
            response.raise_for_status()
            data = response.json()
            
            if data.get("result") != "success":
                logger.error("exchange_rate_api_error", data=data)
                return {}
            
            rates = data.get("rates", {})
            # 只保留主要货币
            filtered_rates = {
                currency: rate 
                for currency, rate in rates.items() 
                if currency in MAJOR_CURRENCIES
            }
            
            logger.info("exchange_rates_fetched", count=len(filtered_rates))
            return filtered_rates
            
        except Exception as e:
            logger.error("exchange_rate_fetch_error", error=str(e))
            return {}


async def update_exchange_rates() -> int:
    """更新汇率到数据库"""
    rates = await fetch_exchange_rates()
    if not rates:
        return 0
    
    today = date.today()
    updated_count = 0
    
    async with async_session() as db:
        for target_currency, rate in rates.items():
            try:
                # 使用 upsert 避免重复
                stmt = pg_insert(ExchangeRate).values(
                    base_currency="CNY",
                    target_currency=target_currency,
                    rate=rate,
                    rate_type="spot",
                    source="open.er-api.com",
                    rate_date=today,
                ).on_conflict_do_update(
                    index_elements=["base_currency", "target_currency", "rate_type", "rate_date"],
                    set_={"rate": rate, "source": "open.er-api.com"}
                )
                await db.execute(stmt)
                updated_count += 1
            except Exception as e:
                logger.error("exchange_rate_save_error", currency=target_currency, error=str(e))
        
        await db.commit()
    
    logger.info("exchange_rates_updated", count=updated_count, date=today.isoformat())
    return updated_count
