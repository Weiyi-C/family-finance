from pydantic import BaseModel, Field


class RegisterRequest(BaseModel):
    phone: str = Field(..., min_length=11, max_length=20)
    password: str = Field(..., min_length=6, max_length=128)
    nickname: str = Field(..., min_length=1, max_length=50)
    family_name: str | None = Field(None, max_length=50)


class LoginRequest(BaseModel):
    phone: str
    password: str


class RefreshRequest(BaseModel):
    refresh_token: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class UserResponse(BaseModel):
    id: int
    nickname: str
    phone: str | None
    avatar_url: str | None
    role: str
    family_id: int | None

    model_config = {"from_attributes": True}


class RegisterResponse(BaseModel):
    user: UserResponse
    tokens: TokenResponse
