from datetime import datetime
from pydantic import BaseModel


class AISuggestionResponse(BaseModel):
    id: int
    family_id: int
    type: str
    status: str
    transaction_ids: list[int] | None = None
    suggestion: dict
    reason: str | None = None
    created_at: datetime | None = None
    resolved_at: datetime | None = None

    model_config = {"from_attributes": True}


class AISuggestionListResponse(BaseModel):
    suggestions: list[AISuggestionResponse]
    total: int
    pending_count: int


class AISuggestionActionRequest(BaseModel):
    action: str  # accept / reject


class AIBatchActionRequest(BaseModel):
    ids: list[int]
    action: str  # accept / reject
