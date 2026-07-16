from pydantic import BaseModel, Field


class AccountCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    type_code: str = Field(..., max_length=30)
    template_id: int | None = None
    icon: str | None = None
    color: str | None = None
    bank_name: str | None = None
    bank_code: str | None = None
    card_tail: str | None = None
    card_type: str | None = None
    initial_balance: int = 0
    credit_limit: int | None = None
    billing_day: int | None = None
    due_day: int | None = None
    grace_days: int | None = None
    is_shared: bool = False
    shared_with: int | None = None
    share_type: str | None = None
    group_name: str | None = None


class AccountUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=100)
    icon: str | None = None
    color: str | None = None
    bank_name: str | None = None
    card_tail: str | None = None
    initial_balance: int | None = None
    credit_limit: int | None = None
    billing_day: int | None = None
    due_day: int | None = None
    is_shared: bool | None = None
    shared_with: int | None = None
    share_type: str | None = None
    sort_order: int | None = None
    is_hidden: bool | None = None


class AccountResponse(BaseModel):
    id: int
    family_id: int
    user_id: int
    template_id: int | None
    name: str
    type_code: str
    icon: str | None
    color: str | None
    bank_name: str | None
    bank_code: str | None
    card_tail: str | None
    card_type: str | None
    initial_balance: int
    credit_limit: int | None
    used_amount: int
    billing_day: int | None
    due_day: int | None
    is_shared: bool
    shared_with: int | None
    share_type: str | None
    group_name: str | None
    sort_order: int
    is_active: bool
    is_hidden: bool

    model_config = {"from_attributes": True}


class AccountBalance(BaseModel):
    id: int
    name: str
    type_code: str
    balance: int
    is_credit: bool
    credit_limit: int | None
    used_amount: int | None
