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
)
from app.database import get_db
from app.models.user import AccountBook, Family, FamilySyncSeq, RefreshToken, User
from app.schemas.sync_register import SyncRegisterRequest, SyncRegisterResponse

logger = structlog.get_logger()
router = APIRouter(prefix="/api/sync", tags=["同步"])


@router.post("/register", response_model=SyncRegisterResponse, status_code=status.HTTP_201_CREATED)
async def sync_register(body: SyncRegisterRequest, db: AsyncSession = Depends(get_db)):
    existing_client = await db.execute(select(User).where(User.client_id == body.client_id))
    existing_user = existing_client.scalar_one_or_none()
    if existing_user:
        family_id = existing_user.family_id
        access_token = create_access_token(existing_user.id, family_id)
        refresh_token = generate_refresh_token()
        db.add(RefreshToken(
            user_id=existing_user.id,
            token_hash=hash_token(refresh_token),
            expires_at=refresh_token_expires_at(),
        ))
        await db.commit()
        logger.info("sync_register_idempotent", user_id=existing_user.id, client_id=body.client_id)
        return SyncRegisterResponse(
            server_id=str(existing_user.id),
            family_id=str(family_id),
            client_id=body.client_id,
            access_token=access_token,
            refresh_token=refresh_token,
        )

    existing_phone = await db.execute(select(User).where(User.phone == body.phone))
    if existing_phone.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="该手机号已注册")

    family = Family(name=f"{body.nickname}的家庭")
    db.add(family)
    await db.flush()

    user = User(
        family_id=family.id,
        client_id=body.client_id,
        nickname=body.nickname,
        phone=body.phone,
        password_hash=hash_password(body.password_hash),
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

    access_token = create_access_token(user.id, family.id)
    refresh_token = generate_refresh_token()
    db.add(RefreshToken(
        user_id=user.id,
        token_hash=hash_token(refresh_token),
        expires_at=refresh_token_expires_at(),
    ))
    await db.commit()

    logger.info("sync_register_success", user_id=user.id, family_id=family.id, client_id=body.client_id)
    return SyncRegisterResponse(
        server_id=str(user.id),
        family_id=str(family.id),
        client_id=body.client_id,
        access_token=access_token,
        refresh_token=refresh_token,
    )
