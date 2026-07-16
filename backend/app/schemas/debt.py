from datetime import date

from pydantic import BaseModel, Field


class RepaymentCreate(BaseModel):
    amount: int = Field(..., gt=0)
    repayment_date: date
    payment_account_id: int | None = None
    description: str | None = None


class DebtCreate(BaseModel):
    type: str = Field(..., pattern="^(lend|borrow)$")
    counterparty: str = Field(..., min_length=1, max_length=100)
    amount: int = Field(..., gt=0)
    currency: str = "CNY"
    payment_account_id: int | None = None
    debt_date: date
    due_date: date | None = None
    description: str | None = None


class DebtUpdate(BaseModel):
    counterparty: str | None = Field(None, min_length=1, max_length=100)
    due_date: date | None = None
    description: str | None = None


class RepaymentResponse(BaseModel):
    id: int
    debt_id: int
    amount: int
    repayment_date: date
    payment_account_id: int | None
    description: str | None

    model_config = {"from_attributes": True}


class DebtResponse(BaseModel):
    id: int
    family_id: int
    type: str
    counterparty: str
    amount: int
    currency: str
    payment_account_id: int | None
    debt_date: date
    due_date: date | None
    status: str
    repaid_amount: int
    description: str | None
    created_by: int
    repayments: list[RepaymentResponse] = []

    model_config = {"from_attributes": True}
