import structlog
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.core.security import hash_password
from app.database import get_db
from app.models.user import Family, User
from app.models.user import FamilySyncSeq

logger = structlog.get_logger()
router = APIRouter(tags=["家庭管理"])


@router.get("/api/families/current")
async def get_current_family(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """获取当前家庭信息"""
    result = await db.execute(select(Family).where(Family.id == current_user.family_id))
    family = result.scalar_one_or_none()
    if not family:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="家庭不存在")
    return {
        "id": family.id,
        "name": family.name,
        "created_by": family.created_by,
        "created_at": family.created_at.isoformat() if family.created_at else None,
    }


@router.put("/api/families/current")
async def update_family(
    body: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """更新家庭信息（仅owner/admin）"""
    if current_user.role not in ("owner", "admin"):
        raise HTTPException(status_code=403, detail="权限不足")

    result = await db.execute(select(Family).where(Family.id == current_user.family_id))
    family = result.scalar_one_or_none()
    if not family:
        raise HTTPException(status_code=404, detail="家庭不存在")

    if "name" in body:
        family.name = body["name"]
    await db.commit()
    await db.refresh(family)
    return {"id": family.id, "name": family.name}


@router.get("/api/families/members")
async def list_members(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """获取家庭成员列表"""
    result = await db.execute(
        select(User).where(User.family_id == current_user.family_id)
    )
    members = result.scalars().all()
    return [
        {
            "id": m.id,
            "nickname": m.nickname,
            "phone": m.phone,
            "avatar_url": m.avatar_url,
            "role": m.role,
        }
        for m in members
    ]


@router.post("/api/families/members")
async def add_member(
    body: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """添加家庭成员（邀请）"""
    if current_user.role not in ("owner", "admin"):
        raise HTTPException(status_code=403, detail="权限不足")

    phone = body.get("phone")
    role = body.get("role", "member")
    if not phone:
        raise HTTPException(status_code=400, detail="请提供手机号")

    # 查找用户
    result = await db.execute(select(User).where(User.phone == phone))
    user = result.scalar_one_or_none()
    if user:
        # 用户已存在，更新家庭归属
        if user.family_id == current_user.family_id:
            raise HTTPException(status_code=400, detail="该用户已是家庭成员")
        user.family_id = current_user.family_id
        user.role = role
        await db.commit()
        return {"id": user.id, "nickname": user.nickname, "role": user.role, "status": "added"}
    else:
        # 用户不存在，创建邀请记录（简化处理：直接创建用户）
        raise HTTPException(status_code=404, detail="用户不存在，请先注册")


@router.put("/api/families/members/{member_id}")
async def update_member(
    member_id: int,
    body: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """更新成员角色"""
    if current_user.role != "owner":
        raise HTTPException(status_code=403, detail="仅owner可修改角色")

    result = await db.execute(
        select(User).where(User.id == member_id, User.family_id == current_user.family_id)
    )
    member = result.scalar_one_or_none()
    if not member:
        raise HTTPException(status_code=404, detail="成员不存在")

    new_role = body.get("role")
    if new_role and new_role in ("admin", "member", "viewer"):
        member.role = new_role
        await db.commit()
    return {"id": member.id, "nickname": member.nickname, "role": member.role}


@router.delete("/api/families/members/{member_id}", status_code=204)
async def remove_member(
    member_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """移除家庭成员"""
    if current_user.role not in ("owner", "admin"):
        raise HTTPException(status_code=403, detail="权限不足")
    if member_id == current_user.id:
        raise HTTPException(status_code=400, detail="不能移除自己")

    result = await db.execute(
        select(User).where(User.id == member_id, User.family_id == current_user.family_id)
    )
    member = result.scalar_one_or_none()
    if not member:
        raise HTTPException(status_code=404, detail="成员不存在")

    member.is_active = False
    await db.commit()


@router.post("/api/families/join")
async def join_family(
    body: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """加入家庭（通过家庭ID或邀请码）"""
    family_id = body.get("family_id")
    if not family_id:
        raise HTTPException(status_code=400, detail="请提供家庭ID")

    result = await db.execute(select(Family).where(Family.id == family_id))
    family = result.scalar_one_or_none()
    if not family:
        raise HTTPException(status_code=404, detail="家庭不存在")

    current_user.family_id = family.id
    current_user.role = "member"
    await db.commit()
    return {"family_id": family.id, "family_name": family.name, "role": "member"}
