from datetime import datetime, timezone

import structlog
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.deps import get_current_user
from app.database import get_db
from app.models.reimbursement import Reimbursement, ReimbursementItem
from app.models.user import User
from app.schemas.reimbursement import (
    ReceiveRequest,
    ReimbursementCreate,
    ReimbursementResponse,
    ReimbursementUpdate,
)

logger = structlog.get_logger()
router = APIRouter(prefix="/api/reimbursements", tags=["报销"])

STATUS_FLOW = {"draft": "submitted", "submitted": "approved", "approved": "received"}


@router.get("", response_model=list[ReimbursementResponse])
async def list_reimbursements(
    status: str | None = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = (
        select(Reimbursement)
        .options(selectinload(Reimbursement.items))
        .where(Reimbursement.family_id == current_user.family_id)
    )
    if status:
        stmt = stmt.where(Reimbursement.status == status)
    stmt = stmt.order_by(Reimbursement.created_at.desc())
    result = await db.execute(stmt)
    return [ReimbursementResponse.model_validate(r) for r in result.scalars()]


@router.post("", response_model=ReimbursementResponse, status_code=status.HTTP_201_CREATED)
async def create_reimbursement(
    body: ReimbursementCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    reimb = Reimbursement(
        family_id=current_user.family_id,
        title=body.title,
        total_amount=body.total_amount,
        description=body.description,
        submitted_by=current_user.id,
    )
    db.add(reimb)
    await db.flush()

    for item in body.items:
        db.add(ReimbursementItem(
            reimbursement_id=reimb.id,
            transaction_id=item.transaction_id,
            amount=item.amount,
            description=item.description,
        ))

    await db.commit()
    await db.refresh(reimb, ["items"])

    logger.info("reimbursement_created", reimb_id=reimb.id)
    return ReimbursementResponse.model_validate(reimb)


@router.get("/{reimb_id}", response_model=ReimbursementResponse)
async def get_reimbursement(
    reimb_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Reimbursement)
        .options(selectinload(Reimbursement.items))
        .where(Reimbursement.id == reimb_id, Reimbursement.family_id == current_user.family_id)
    )
    reimb = result.scalar_one_or_none()
    if not reimb:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="报销单不存在")
    return ReimbursementResponse.model_validate(reimb)


@router.put("/{reimb_id}", response_model=ReimbursementResponse)
async def update_reimbursement(
    reimb_id: int,
    body: ReimbursementUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Reimbursement)
        .options(selectinload(Reimbursement.items))
        .where(Reimbursement.id == reimb_id, Reimbursement.family_id == current_user.family_id)
    )
    reimb = result.scalar_one_or_none()
    if not reimb:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="报销单不存在")
    if reimb.status != "draft":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="只有草稿状态可编辑")

    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(reimb, field, value)

    await db.commit()
    await db.refresh(reimb, ["items"])
    return ReimbursementResponse.model_validate(reimb)


@router.post("/{reimb_id}/submit", response_model=ReimbursementResponse)
async def submit_reimbursement(
    reimb_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Reimbursement)
        .options(selectinload(Reimbursement.items))
        .where(Reimbursement.id == reimb_id, Reimbursement.family_id == current_user.family_id)
    )
    reimb = result.scalar_one_or_none()
    if not reimb:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="报销单不存在")
    if reimb.status != "draft":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="只有草稿可提交")

    reimb.status = "submitted"
    reimb.submitted_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(reimb, ["items"])

    logger.info("reimbursement_submitted", reimb_id=reimb_id)
    return ReimbursementResponse.model_validate(reimb)


@router.post("/{reimb_id}/approve", response_model=ReimbursementResponse)
async def approve_reimbursement(
    reimb_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Reimbursement)
        .options(selectinload(Reimbursement.items))
        .where(Reimbursement.id == reimb_id, Reimbursement.family_id == current_user.family_id)
    )
    reimb = result.scalar_one_or_none()
    if not reimb:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="报销单不存在")
    if reimb.status != "submitted":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="只有已提交状态可审批")

    reimb.status = "approved"
    reimb.approved_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(reimb, ["items"])

    logger.info("reimbursement_approved", reimb_id=reimb_id)
    return ReimbursementResponse.model_validate(reimb)


@router.post("/{reimb_id}/receive", response_model=ReimbursementResponse)
async def receive_reimbursement(
    reimb_id: int,
    body: ReceiveRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Reimbursement)
        .options(selectinload(Reimbursement.items))
        .where(Reimbursement.id == reimb_id, Reimbursement.family_id == current_user.family_id)
    )
    reimb = result.scalar_one_or_none()
    if not reimb:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="报销单不存在")
    if reimb.status != "approved":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="只有已审批状态可确认到账")

    reimb.status = "received"
    reimb.received_at = datetime.now(timezone.utc)
    reimb.received_amount = body.received_amount
    await db.commit()
    await db.refresh(reimb, ["items"])

    logger.info("reimbursement_received", reimb_id=reimb_id, amount=body.received_amount)
    return ReimbursementResponse.model_validate(reimb)


@router.delete("/{reimb_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_reimbursement(
    reimb_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Reimbursement).where(
            Reimbursement.id == reimb_id,
            Reimbursement.family_id == current_user.family_id,
        )
    )
    reimb = result.scalar_one_or_none()
    if not reimb:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="报销单不存在")
    if reimb.status != "draft":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="只有草稿可删除")

    await db.delete(reimb)
    await db.commit()

    logger.info("reimbursement_deleted", reimb_id=reimb_id)
