"""定时任务调度器"""

import asyncio
import structlog
from sqlalchemy import select

from app.models.user import Family
from app.services.ai_analyzer import AIAnalyzer
from app.services.recurring_service import run_recurring_job
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
                # 等待1小时避免重复执行
                await asyncio.sleep(3600)
            else:
                await asyncio.sleep(300)  # 每5分钟检查一次
        except Exception as e:
            logger.error("scheduler_error", error=str(e))
            await asyncio.sleep(60)


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
            # 每天凌晨2点执行
            if now.hour == 2:
                await run_ai_analysis_job()
                # 等待1小时避免重复执行
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
