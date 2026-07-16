from datetime import datetime

from pydantic import BaseModel, Field


class ReimbursementItemCreate(BaseModel):
    transaction_id: int
    amount: int = Field(..., gt=0)
    description: str | None = None


class ReimbursementCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    total_amount: int = Field(..., gt=0)
    description: str | None = None
    items: list[ReimbursementItemCreate] = []


class ReimbursementUpdate(BaseModel):
    title: str | None = Field(None, min_length=1, max_length=200)
    total_amount: int | None = Field(None, gt=0)
    description: str | None = None


class ReimbursementItemResponse(BaseModel):
    id: int
    reimbursement_id: int
    transaction_id: int
    amount: int
    description: str | None

    model_config = {"from_attributes": True}


class ReimbursementResponse(BaseModel):
    id: int
    family_id: int
    title: str
    total_amount: int
    status: str
    submitted_at: datetime | None
    approved_at: datetime | None
    received_at: datetime | None
    received_amount: int | None
    submitted_by: int
    description: str | None
    items: list[ReimbursementItemResponse] = []

    model_config = {"from_attributes": True}


class ReceiveRequest(BaseModel):
    received_amount: int = Field(..., gt=0)
