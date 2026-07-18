from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.database import get_db
from app.models.user import User
from app.schemas.auth import UserResponse

router = APIRouter(prefix="/api/users", tags=["用户"])


@router.get("/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(get_current_user)):
    return UserResponse.model_validate(current_user)


@router.put("/me")
async def update_me(
    body: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """更新用户信息"""
    if "nickname" in body:
        current_user.nickname = body["nickname"]
    if "avatar_url" in body:
        current_user.avatar_url = body["avatar_url"]
    if "phone" in body:
        # 检查手机号是否已被使用
        from sqlalchemy import select
        existing = await db.execute(
            select(User).where(User.phone == body["phone"], User.id != current_user.id)
        )
        if existing.scalar_one_or_none():
            raise HTTPException(status_code=400, detail="手机号已被使用")
        current_user.phone = body["phone"]

    await db.commit()
    await db.refresh(current_user)
    return UserResponse.model_validate(current_user)
