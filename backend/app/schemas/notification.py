from datetime import datetime, timezone

from pydantic import BaseModel


class NotificationResponse(BaseModel):
    id: int
    user_id: int
    family_id: int
    type: str
    title: str
    content: str | None
    related_id: int | None
    related_type: str | None
    is_read: bool
    read_at: datetime | None
    channel: str
    send_status: str

    model_config = {"from_attributes": True}
