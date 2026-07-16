import structlog
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.database import get_db
from app.models.channel import PaymentChannel
from app.models.platform import Platform
from app.models.user import User
from app.schemas.channel import (
    ChannelCreate,
    ChannelResponse,
    ChannelUpdate,
    PlatformCreate,
    PlatformResponse,
    PlatformUpdate,
)

logger = structlog.get_logger()
router = APIRouter(tags=["支付渠道/平台"])


# ---- Payment Channels ----

@router.get("/api/channels", response_model=list[ChannelResponse])
async def list_channels(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(PaymentChannel)
        .where(
            (PaymentChannel.family_id.is_(None)) | (PaymentChannel.family_id == current_user.family_id),
            PaymentChannel.is_active == True,
        )
        .order_by(PaymentChannel.sort_order, PaymentChannel.id)
    )
    return [ChannelResponse.model_validate(c) for c in result.scalars()]


@router.post("/api/channels", response_model=ChannelResponse, status_code=status.HTTP_201_CREATED)
async def create_channel(
    body: ChannelCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    channel = PaymentChannel(
        family_id=current_user.family_id,
        name=body.name,
        icon=body.icon,
        sort_order=body.sort_order,
    )
    db.add(channel)
    await db.commit()
    await db.refresh(channel)
    return ChannelResponse.model_validate(channel)


@router.put("/api/channels/{channel_id}", response_model=ChannelResponse)
async def update_channel(
    channel_id: int,
    body: ChannelUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(PaymentChannel).where(PaymentChannel.id == channel_id)
    )
    channel = result.scalar_one_or_none()
    if not channel:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="支付渠道不存在")
    if channel.family_id is None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="系统渠道不可修改")
    if channel.family_id != current_user.family_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="支付渠道不存在")

    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(channel, field, value)
    await db.commit()
    await db.refresh(channel)
    return ChannelResponse.model_validate(channel)


@router.delete("/api/channels/{channel_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_channel(
    channel_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(PaymentChannel).where(PaymentChannel.id == channel_id)
    )
    channel = result.scalar_one_or_none()
    if not channel:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="支付渠道不存在")
    if channel.family_id is None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="系统渠道不可删除")
    if channel.family_id != current_user.family_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="支付渠道不存在")

    channel.is_active = False
    await db.commit()


# ---- Platforms ----

@router.get("/api/platforms", response_model=list[PlatformResponse])
async def list_platforms(
    type: str | None = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(Platform).where(
        (Platform.family_id.is_(None)) | (Platform.family_id == current_user.family_id),
        Platform.is_active == True,
    )
    if type:
        stmt = stmt.where(Platform.type == type)
    stmt = stmt.order_by(Platform.sort_order, Platform.id)
    result = await db.execute(stmt)
    return [PlatformResponse.model_validate(p) for p in result.scalars()]


@router.post("/api/platforms", response_model=PlatformResponse, status_code=status.HTTP_201_CREATED)
async def create_platform(
    body: PlatformCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    platform = Platform(
        family_id=current_user.family_id,
        name=body.name,
        type=body.type,
        icon=body.icon,
        sort_order=body.sort_order,
    )
    db.add(platform)
    await db.commit()
    await db.refresh(platform)
    return PlatformResponse.model_validate(platform)


@router.put("/api/platforms/{platform_id}", response_model=PlatformResponse)
async def update_platform(
    platform_id: int,
    body: PlatformUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Platform).where(Platform.id == platform_id)
    )
    platform = result.scalar_one_or_none()
    if not platform:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="平台不存在")
    if platform.family_id is None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="系统平台不可修改")
    if platform.family_id != current_user.family_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="平台不存在")

    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(platform, field, value)
    await db.commit()
    await db.refresh(platform)
    return PlatformResponse.model_validate(platform)


@router.delete("/api/platforms/{platform_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_platform(
    platform_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Platform).where(Platform.id == platform_id)
    )
    platform = result.scalar_one_or_none()
    if not platform:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="平台不存在")
    if platform.family_id is None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="系统平台不可删除")
    if platform.family_id != current_user.family_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="平台不存在")

    platform.is_active = False
    await db.commit()
