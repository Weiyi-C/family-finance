from datetime import datetime

from pydantic import BaseModel, Field


class TransactionCreate(BaseModel):
    book_id: int
    type: str = Field(..., pattern="^(expense|income|transfer)$")
    amount: int = Field(..., gt=0)
    currency: str = "CNY"
    category_id: int | None = None
    sub_category_id: int | None = None
    detail_category_id: int | None = None
    payment_account_id: int | None = None
    payment_channel_id: int | None = None
    platform_id: int | None = None
    merchant_name: str | None = None
    description: str | None = None
    transaction_time: datetime
    paid_by: int | None = None
    is_quick_entry: bool = False
    completion_status: str = "complete"
    tag_ids: list[int] = []


class TransactionUpdate(BaseModel):
    book_id: int | None = None
    amount: int | None = Field(None, gt=0)
    currency: str | None = None
    category_id: int | None = None
    sub_category_id: int | None = None
    detail_category_id: int | None = None
    payment_account_id: int | None = None
    payment_channel_id: int | None = None
    platform_id: int | None = None
    merchant_name: str | None = None
    description: str | None = None
    transaction_time: datetime | None = None
    paid_by: int | None = None
    completion_status: str | None = None
    tag_ids: list[int] | None = None


class TransactionResponse(BaseModel):
    id: int
    family_id: int
    book_id: int
    entry_id: int | None
    type: str
    amount: int
    currency: str
    original_amount: int | None
    original_currency: str | None
    exchange_rate: float | None
    category_id: int | None
    sub_category_id: int | None
    detail_category_id: int | None
    payment_account_id: int | None
    payment_channel_id: int | None
    platform_id: int | None
    merchant_name: str | None
    description: str | None
    transaction_time: datetime
    recorded_by: int
    paid_by: int | None
    is_quick_entry: bool
    completion_status: str
    version: int
    tag_ids: list[int] = []

    model_config = {"from_attributes": True}


class TransactionListParams(BaseModel):
    book_id: int | None = None
    type: str | None = None
    category_id: int | None = None
    payment_account_id: int | None = None
    merchant_name: str | None = None
    keyword: str | None = None
    start_date: datetime | None = None
    end_date: datetime | None = None
    min_amount: int | None = None
    max_amount: int | None = None
    page: int = 1
    page_size: int = 20
