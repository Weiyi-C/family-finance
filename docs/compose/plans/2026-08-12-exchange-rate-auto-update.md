# Exchange Rate Auto-Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use compose:subagent (recommended) or compose:execute to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement automatic daily exchange rate updates from free API

**Architecture:** Create a service to fetch rates from open.er-api.com, store in database, and run daily via scheduler

**Tech Stack:** Python, httpx, SQLAlchemy, APScheduler

---

## File Structure

```
backend/app/services/
├── exchange_rate_service.py  # NEW - fetch and store rates
└── scheduler.py              # MODIFY - add rate update job, fix duplicate function
```

---

### Task 1: Create Exchange Rate Service

**Covers:** Core functionality for fetching and storing rates

**Files:**
- Create: `backend/app/services/exchange_rate_service.py`

- [ ] **Step 1: Create the service file**

```python
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
```

- [ ] **Step 2: Verify the service can be imported**

Run: `cd /home/weiyi/Projects/family-finance/backend && python -c "from app.services.exchange_rate_service import update_exchange_rates; print('Import OK')"`
Expected: "Import OK"

---

### Task 2: Fix Scheduler and Add Rate Update Job

**Covers:** Integrate rate update into daily scheduler

**Files:**
- Modify: `backend/app/services/scheduler.py`

- [ ] **Step 1: Update scheduler.py**

Remove the duplicate `start_scheduler` function and add the exchange rate update job.

```python
"""定时任务调度器"""

import asyncio
import structlog
from sqlalchemy import select

from app.models.user import Family
from app.services.ai_analyzer import AIAnalyzer
from app.services.recurring_service import run_recurring_job
from app.services.notify_service import run_notify_job
from app.services.clean_service import run_clean_job
from app.services.analyze_service import run_analyze_job
from app.services.exchange_rate_service import update_exchange_rates
from app.database import async_session

logger = structlog.get_logger()

_scheduler_running = False


async def run_ai_analysis_job():
    """定时AI分析任务：遍历所有已配置AI的家庭，执行分析"""
    async with async_session() as db:
        result = await db.execute(select(Family))
        families = result.scalars().all()

        total_suggestions = 0
        for family in families:
            try:
                settings = family.settings or {}
                if not settings.get("ai", {}).get("enabled"):
                    continue
                analyzer = AIAnalyzer(family_id=family.id, family_settings=settings)
                suggestions = await analyzer.run_analysis(db)
                total_suggestions += len(suggestions)
                if suggestions:
                    from app.models.notification import Notification
                    notif = Notification(
                        family_id=family.id,
                        user_id=family.created_by,
                        type="ai_suggestion",
                        title="AI 分析完成",
                        content=f"AI 发现了 {len(suggestions)} 条新建议",
                        related_type="ai_suggestion",
                    )
                    db.add(notif)
                    await db.commit()
            except Exception as e:
                logger.error("ai_analysis_job_error", family_id=family.id, error=str(e))

        logger.info("ai_analysis_job_complete", families=len(families), suggestions=total_suggestions)


async def run_exchange_rate_job():
    """定时汇率更新任务"""
    try:
        count = await update_exchange_rates()
        logger.info("exchange_rate_job_complete", updated=count)
    except Exception as e:
        logger.error("exchange_rate_job_error", error=str(e))


async def start_scheduler():
    """启动定时任务调度器"""
    global _scheduler_running
    if _scheduler_running:
        return
    _scheduler_running = True
    logger.info("scheduler_started")

    while _scheduler_running:
        try:
            from datetime import datetime
            now = datetime.now()
            
            # 每天凌晨2点执行周期交易和AI分析
            if now.hour == 2:
                await run_recurring_job()
                await run_ai_analysis_job()
                # 每周日执行数据清洗和分析洞察
                if now.weekday() == 6:
                    await run_clean_job()
                    await run_analyze_job()
                await asyncio.sleep(3600)
            
            # 每天凌晨3点执行汇率更新
            elif now.hour == 3:
                await run_exchange_rate_job()
                await asyncio.sleep(3600)
            
            # 每天早上8点执行提醒通知
            elif now.hour == 8:
                await run_notify_job()
                await asyncio.sleep(3600)
            
            else:
                await asyncio.sleep(300)  # 每5分钟检查一次
                
        except Exception as e:
            logger.error("scheduler_error", error=str(e))
            await asyncio.sleep(60)


def stop_scheduler():
    """停止调度器"""
    global _scheduler_running
    _scheduler_running = False
    logger.info("scheduler_stopped")
```

- [ ] **Step 2: Verify scheduler imports correctly**

Run: `cd /home/weiyi/Projects/family-finance/backend && python -c "from app.services.scheduler import start_scheduler; print('Scheduler import OK')"`
Expected: "Scheduler import OK"

---

### Task 3: Test Exchange Rate Service

**Covers:** Verify the service works correctly

**Files:**
- Test: Manual verification

- [ ] **Step 1: Run the exchange rate update manually**

Run: `cd /home/weiyi/Projects/family-finance/backend && python -c "import asyncio; from app.services.exchange_rate_service import update_exchange_rates; print(asyncio.run(update_exchange_rates()))"`
Expected: Output showing number of rates updated (e.g., 30)

- [ ] **Step 2: Verify rates are stored in database**

Run: `docker exec ff-db psql -U ff_user -d family_finance -c "SELECT COUNT(*) FROM exchange_rates WHERE rate_date = CURRENT_DATE;"`
Expected: Count matching the number of currencies (around 30)

- [ ] **Step 3: Test the API endpoint**

Run: `curl -s http://localhost:8000/api/exchange-rates | python3 -m json.tool | head -20`
Expected: JSON array with exchange rate data

- [ ] **Step 4: Commit the changes**

```bash
cd /home/weiyi/Projects/family-finance
git add backend/app/services/exchange_rate_service.py backend/app/services/scheduler.py
git commit -m "feat: 实现汇率自动更新功能"
```

---

## Summary

This plan implements automatic daily exchange rate updates:
1. Creates a service to fetch rates from open.er-api.com
2. Stores rates in the database with upsert to avoid duplicates
3. Integrates with the existing scheduler to run daily at 3 AM
4. Fixes the duplicate `start_scheduler` function bug
