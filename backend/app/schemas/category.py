from pydantic import BaseModel, Field


class CategoryCreate(BaseModel):
    parent_id: int | None = None
    name: str = Field(..., min_length=1, max_length=50)
    icon: str | None = Field(None, max_length=50)
    color: str | None = Field(None, max_length=20)
    type: str = Field("expense", pattern="^(expense|income)$")
    sort_order: int = 0


class CategoryUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=50)
    icon: str | None = None
    color: str | None = None
    sort_order: int | None = None
    is_active: bool | None = None


class CategoryResponse(BaseModel):
    id: int
    parent_id: int | None
    level: int
    name: str
    icon: str | None
    color: str | None
    type: str
    sort_order: int
    is_active: bool
    is_system: bool

    model_config = {"from_attributes": True}


class CategoryTreeNode(BaseModel):
    id: int
    name: str
    icon: str | None
    color: str | None
    type: str
    sort_order: int
    is_active: bool
    is_system: bool
    children: list["CategoryTreeNode"] = []

    model_config = {"from_attributes": True}
