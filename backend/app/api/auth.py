import structlog
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import (
    create_access_token,
    generate_refresh_token,
    hash_password,
    hash_token,
    refresh_token_expires_at,
    verify_password,
)
from app.database import get_db
from app.models.user import AccountBook, Family, FamilySyncSeq, RefreshToken, User
from app.schemas.auth import (
    LoginRequest,
    RefreshRequest,
    RegisterRequest,
    RegisterResponse,
    TokenResponse,
    UserResponse,
)

logger = structlog.get_logger()
router = APIRouter(prefix="/api/auth", tags=["认证"])


async def _create_token_pair(user: User, db: AsyncSession) -> TokenResponse:
    access_token = create_access_token(user.id, user.family_id)
    refresh_token = generate_refresh_token()
    db.add(RefreshToken(
        user_id=user.id,
        token_hash=hash_token(refresh_token),
        expires_at=refresh_token_expires_at(),
    ))
    await db.flush()
    return TokenResponse(access_token=access_token, refresh_token=refresh_token)


@router.post("/register", response_model=RegisterResponse, status_code=status.HTTP_201_CREATED)
async def register(body: RegisterRequest, db: AsyncSession = Depends(get_db)):
    existing = await db.execute(select(User).where(User.phone == body.phone))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="该手机号已注册")

    family_name = body.family_name or f"{body.nickname}的家庭"
    family = Family(name=family_name)
    db.add(family)
    await db.flush()

    user = User(
        family_id=family.id,
        nickname=body.nickname,
        phone=body.phone,
        password_hash=hash_password(body.password),
        role="owner",
    )
    db.add(user)
    await db.flush()

    family.created_by = user.id
    db.add(AccountBook(
        family_id=family.id,
        name="日常",
        icon="📖",
        is_default=True,
        created_by=user.id,
    ))
    db.add(FamilySyncSeq(family_id=family.id, current_seq=0))

    tokens = await _create_token_pair(user, db)
    await db.commit()

    logger.info("user_registered", user_id=user.id, family_id=family.id)
    return RegisterResponse(user=UserResponse.model_validate(user), tokens=tokens)


@router.post("/login", response_model=TokenResponse)
async def login(body: LoginRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.phone == body.phone))
    user = result.scalar_one_or_none()
    if not user or not user.password_hash or not verify_password(body.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="手机号或密码错误")

    tokens = await _create_token_pair(user, db)
    await db.commit()

    logger.info("user_logged_in", user_id=user.id)
    return tokens


@router.post("/refresh", response_model=TokenResponse)
async def refresh(body: RefreshRequest, db: AsyncSession = Depends(get_db)):
    token_hash = hash_token(body.refresh_token)
    result = await db.execute(select(RefreshToken).where(RefreshToken.token_hash == token_hash))
    record = result.scalar_one_or_none()

    if not record:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="无效的刷新令牌")

    from datetime import datetime, timezone
    if record.expires_at.replace(tzinfo=timezone.utc) < datetime.now(timezone.utc):
        await db.delete(record)
        await db.commit()
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="刷新令牌已过期")

    user_result = await db.execute(select(User).where(User.id == record.user_id))
    user = user_result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="用户不存在")

    await db.delete(record)
    tokens = await _create_token_pair(user, db)
    await db.commit()

    return tokens


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(body: RefreshRequest, db: AsyncSession = Depends(get_db)):
    token_hash = hash_token(body.refresh_token)
    result = await db.execute(select(RefreshToken).where(RefreshToken.token_hash == token_hash))
    record = result.scalar_one_or_none()
    if record:
        await db.delete(record)
        await db.commit()
