from datetime import date

from pydantic import BaseModel, Field


class BudgetCreate(BaseModel):
    book_id: int | None = None
    category_id: int | None = None
    amount: int = Field(..., gt=0)
    currency: str = "CNY"
    period: str = Field(..., pattern="^(monthly|weekly|yearly)$")
    year: int = Field(..., ge=2020, le=2100)
    month: int | None = Field(None, ge=1, le=12)
    week_start_date: date | None = None
    rollover: bool = False
    alert_threshold: float = Field(0.8, ge=0, le=1)


class BudgetUpdate(BaseModel):
    amount: int | None = Field(None, gt=0)
    rollover: bool | None = None
    alert_threshold: float | None = Field(None, ge=0, le=1)


class BudgetResponse(BaseModel):
    id: int
    family_id: int
    book_id: int | None
    category_id: int | None
    amount: int
    currency: str
    period: str
    year: int
    month: int | None
    week_start_date: date | None
    rollover: bool
    rollover_amount: int
    alert_threshold: float

    model_config = {"from_attributes": True}


class BudgetUsage(BaseModel):
    budget_id: int
    amount: int
    spent: int
    remaining: int
    usage_rate: float
    is_over: bool
    period_start: date
    period_end: date
