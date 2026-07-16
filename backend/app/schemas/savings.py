from datetime import date, datetime

from pydantic import BaseModel, Field


class SavingsGoalCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    icon: str | None = None
    color: str | None = None
    target_amount: int = Field(..., gt=0)
    account_id: int | None = None
    start_date: date
    target_date: date | None = None


class SavingsGoalUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=100)
    icon: str | None = None
    color: str | None = None
    target_amount: int | None = Field(None, gt=0)
    target_date: date | None = None


class DepositRequest(BaseModel):
    amount: int = Field(..., gt=0)


class SavingsGoalResponse(BaseModel):
    id: int
    family_id: int
    name: str
    icon: str | None
    color: str | None
    target_amount: int
    current_amount: int
    account_id: int | None
    start_date: date
    target_date: date | None
    status: str
    achieved_at: datetime | None
    created_by: int
    progress: float = 0

    model_config = {"from_attributes": True}
