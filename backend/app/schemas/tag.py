from pydantic import BaseModel, Field


class TagCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=50)
    color: str | None = Field(None, max_length=20)


class TagUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=50)
    color: str | None = None


class TagResponse(BaseModel):
    id: int
    family_id: int
    name: str
    color: str | None

    model_config = {"from_attributes": True}
