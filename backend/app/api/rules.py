import structlog
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.database import get_db
from app.models.rule import AutomationRule
from app.models.user import User
from app.schemas.extra import RuleCreate, RuleUpdate, RuleResponse, RuleTestRequest

logger = structlog.get_logger()
router = APIRouter(tags=["规则引擎"])


@router.get("/api/rules", response_model=list[RuleResponse])
async def list_rules(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(AutomationRule)
        .where(AutomationRule.family_id == current_user.family_id)
        .order_by(AutomationRule.priority.desc())
    )
    return [RuleResponse.model_validate(r) for r in result.scalars()]


@router.post("/api/rules", response_model=RuleResponse, status_code=201)
async def create_rule(
    body: RuleCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    rule = AutomationRule(family_id=current_user.family_id, **body.model_dump())
    db.add(rule)
    await db.commit()
    await db.refresh(rule)
    return RuleResponse.model_validate(rule)


@router.put("/api/rules/{rule_id}", response_model=RuleResponse)
async def update_rule(
    rule_id: int,
    body: RuleUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(AutomationRule).where(
            AutomationRule.id == rule_id,
            AutomationRule.family_id == current_user.family_id,
        )
    )
    rule = result.scalar_one_or_none()
    if not rule:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="规则不存在")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(rule, field, value)
    await db.commit()
    await db.refresh(rule)
    return RuleResponse.model_validate(rule)


@router.delete("/api/rules/{rule_id}", status_code=204)
async def delete_rule(
    rule_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(AutomationRule).where(
            AutomationRule.id == rule_id,
            AutomationRule.family_id == current_user.family_id,
        )
    )
    rule = result.scalar_one_or_none()
    if not rule:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="规则不存在")
    await db.delete(rule)
    await db.commit()


@router.post("/api/rules/test")
async def test_rule(
    body: RuleTestRequest,
    current_user: User = Depends(get_current_user),
):
    matched = True
    for key, expected in body.conditions.items():
        actual = body.test_data.get(key)
        if actual != expected:
            matched = False
            break
    return {"matched": matched, "test_data": body.test_data, "conditions": body.conditions}
