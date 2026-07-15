from pydantic import BaseModel, Field


class BookCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=50)
    icon: str | None = Field(None, max_length=50)
    color: str | None = Field(None, max_length=20)
    description: str | None = Field(None, max_length=200)


class BookUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=50)
    icon: str | None = None
    color: str | None = None
    description: str | None = None


class BookResponse(BaseModel):
    id: int
    family_id: int
    name: str
    icon: str | None
    color: str | None
    description: str | None
    is_default: bool
    is_archived: bool
    created_by: int | None

    model_config = {"from_attributes": True}
