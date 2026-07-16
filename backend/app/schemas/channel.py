from pydantic import BaseModel, Field


class ChannelCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=50)
    icon: str | None = None
    sort_order: int = 0


class ChannelUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=50)
    icon: str | None = None
    sort_order: int | None = None
    is_active: bool | None = None


class ChannelResponse(BaseModel):
    id: int
    family_id: int | None
    name: str
    icon: str | None
    sort_order: int
    is_active: bool

    model_config = {"from_attributes": True}


class PlatformCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    type: str = Field(..., pattern="^(online|offline)$")
    icon: str | None = None
    sort_order: int = 0


class PlatformUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=100)
    type: str | None = Field(None, pattern="^(online|offline)$")
    icon: str | None = None
    sort_order: int | None = None
    is_active: bool | None = None


class PlatformResponse(BaseModel):
    id: int
    family_id: int | None
    name: str
    type: str
    icon: str | None
    sort_order: int
    is_active: bool

    model_config = {"from_attributes": True}
