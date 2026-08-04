"""AI 配置 API"""

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.database import get_db
from app.models.user import User
from app.services.ai_service import AI_PROVIDERS, AIService

router = APIRouter(tags=["AI配置"])


class AISettings(BaseModel):
    provider: str  # openai, dashscope, deepseek, custom
    api_key: str
    base_url: str | None = None
    model: str | None = None
    enabled: bool = True


class AISettingsResponse(BaseModel):
    provider: str
    api_key_masked: str  # 掩码后的 API Key
    base_url: str
    model: str
    enabled: bool


@router.get("/api/ai/providers")
async def list_providers():
    """获取支持的 AI 提供商列表"""
    return [
        {
            "id": provider_id,
            "name": config["name"],
            "models": config["models"],
            "default_model": config["default_model"],
        }
        for provider_id, config in AI_PROVIDERS.items()
    ]


@router.get("/api/ai/settings", response_model=AISettingsResponse)
async def get_ai_settings(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """获取当前家庭的 AI 配置"""
    from app.models.user import Family
    from sqlalchemy import select

    # 从数据库加载家庭设置
    result = await db.execute(
        select(Family.settings).where(Family.id == current_user.family_id)
    )
    row = result.first()
    settings = row[0] if row else {}
    ai_config = (settings or {}).get("ai", {})

    api_key = ai_config.get("api_key", "")
    # 掩码处理：只显示前 8 位和后 4 位
    if len(api_key) > 12:
        api_key_masked = f"{api_key[:8]}...{api_key[-4:]}"
    elif api_key:
        api_key_masked = f"{api_key[:4]}..."
    else:
        api_key_masked = ""

    return AISettingsResponse(
        provider=ai_config.get("provider", ""),
        api_key_masked=api_key_masked,
        base_url=ai_config.get("base_url", ""),
        model=ai_config.get("model", ""),
        enabled=ai_config.get("enabled", False),
    )


@router.put("/api/ai/settings")
async def update_ai_settings(
    body: AISettings,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """更新家庭的 AI 配置"""
    # 验证 provider
    if body.provider not in AI_PROVIDERS:
        raise HTTPException(status_code=400, detail=f"不支持的 AI 提供商: {body.provider}")

    # 获取提供商配置
    provider_config = AI_PROVIDERS[body.provider]

    # 如果是自定义提供商，必须提供 base_url
    if body.provider == "custom" and not body.base_url:
        raise HTTPException(status_code=400, detail="自定义提供商必须提供 API 地址")

    # 验证 API Key 格式（简单验证）
    if not body.api_key or len(body.api_key) < 10:
        raise HTTPException(status_code=400, detail="API Key 格式不正确")

    # 更新家庭设置
    from app.models.user import Family
    from sqlalchemy import select, update as sql_update

    result = await db.execute(select(Family).where(Family.id == current_user.family_id))
    family = result.scalar_one_or_none()

    if not family:
        raise HTTPException(status_code=404, detail="家庭不存在")

    # 检查权限（只有 owner 和 admin 可以修改）
    if current_user.role not in ("owner", "admin"):
        raise HTTPException(status_code=403, detail="只有管理员可以修改 AI 配置")

    # 使用 SQLAlchemy 的 update 语句确保 JSONB 更新生效
    new_settings = (family.settings or {}).copy()
    new_settings["ai"] = {
        "provider": body.provider,
        "api_key": body.api_key,
        "base_url": body.base_url or provider_config["base_url"],
        "model": body.model or provider_config["default_model"],
        "enabled": body.enabled,
    }

    await db.execute(
        sql_update(Family)
        .where(Family.id == current_user.family_id)
        .values(settings=new_settings)
    )
    await db.commit()

    return {"message": "AI 配置已更新"}


@router.delete("/api/ai/settings")
async def delete_ai_settings(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """删除家庭的 AI 配置"""
    from app.models.user import Family
    from sqlalchemy import select, update as sql_update

    result = await db.execute(select(Family).where(Family.id == current_user.family_id))
    family = result.scalar_one_or_none()

    if not family:
        raise HTTPException(status_code=404, detail="家庭不存在")

    if current_user.role not in ("owner", "admin"):
        raise HTTPException(status_code=403, detail="只有管理员可以修改 AI 配置")

    new_settings = (family.settings or {}).copy()
    new_settings.pop("ai", None)

    await db.execute(
        sql_update(Family)
        .where(Family.id == current_user.family_id)
        .values(settings=new_settings)
    )
    await db.commit()

    return {"message": "AI 配置已删除"}


@router.post("/api/ai/test")
async def test_ai_connection(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """测试 AI 连接"""
    from app.models.user import Family
    from sqlalchemy import select

    result = await db.execute(select(Family).where(Family.id == current_user.family_id))
    family = result.scalar_one_or_none()

    settings = family.settings if family else {}
    ai_config = (settings or {}).get("ai", {})

    if not ai_config.get("enabled"):
        raise HTTPException(status_code=400, detail="AI 功能未启用")

    from app.services.ai_service import get_ai_service
    ai_service = get_ai_service(settings)

    if not ai_service:
        raise HTTPException(status_code=400, detail="AI 配置无效")

    # 测试调用
    try:
        result = await ai_service._call_llm("请回复'连接成功'四个字")
        if result:
            return {"message": "AI 连接测试成功", "response": result[:100]}
        else:
            raise HTTPException(status_code=500, detail="AI 返回为空")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI 连接测试失败: {str(e)}")
