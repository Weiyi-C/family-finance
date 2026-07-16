from datetime import date, time

from pydantic import BaseModel, Field


class RecurringCreate(BaseModel):
    book_id: int
    type: str = Field(..., pattern="^(expense|income|transfer)$")
    amount: int = Field(..., gt=0)
    currency: str = "CNY"
    category_id: int | None = None
    sub_category_id: int | None = None
    payment_account_id: int | None = None
    payment_channel_id: int | None = None
    platform_id: int | None = None
    merchant_name: str | None = None
    description: str | None = None
    frequency: str = Field(..., pattern="^(daily|weekly|monthly|yearly)$")
    day_of_month: int | None = Field(None, ge=1, le=31)
    day_of_week: int | None = Field(None, ge=0, le=6)
    month_of_year: int | None = Field(None, ge=1, le=12)
    interval_value: int = 1
    start_date: date
    end_date: date | None = None
    remind_days_before: int = 1
    remind_time: time | None = None


class RecurringUpdate(BaseModel):
    amount: int | None = Field(None, gt=0)
    category_id: int | None = None
    sub_category_id: int | None = None
    payment_account_id: int | None = None
    merchant_name: str | None = None
    description: str | None = None
    frequency: str | None = Field(None, pattern="^(daily|weekly|monthly|yearly)$")
    day_of_month: int | None = None
    day_of_week: int | None = None
    interval_value: int | None = None
    end_date: date | None = None
    remind_days_before: int | None = None
    remind_time: time | None = None
    is_active: bool | None = None


class RecurringLogResponse(BaseModel):
    id: int
    recurring_id: int
    transaction_id: int | None
    scheduled_date: date
    actual_date: date | None
    status: str
    amount: int | None
    note: str | None

    model_config = {"from_attributes": True}


class RecurringResponse(BaseModel):
    id: int
    family_id: int
    book_id: int
    type: str
    amount: int
    currency: str
    category_id: int | None
    sub_category_id: int | None
    payment_account_id: int | None
    payment_channel_id: int | None
    platform_id: int | None
    merchant_name: str | None
    description: str | None
    frequency: str
    day_of_month: int | None
    day_of_week: int | None
    month_of_year: int | None
    interval_value: int
    start_date: date
    end_date: date | None
    remind_days_before: int
    remind_time: time | None
    is_active: bool
    last_generated: date | None
    next_generate: date | None
    total_generated: int
    created_by: int

    model_config = {"from_attributes": True}
