from pydantic import BaseModel, Field


class SyncRegisterRequest(BaseModel):
    client_id: str = Field(..., description="客户端生成的 UUID")
    phone: str = Field(..., min_length=11, max_length=20)
    password_hash: str = Field(...)
    nickname: str = Field(..., min_length=1, max_length=50)


class SyncRegisterResponse(BaseModel):
    server_id: str
    family_id: str
    client_id: str
    access_token: str
    refresh_token: str
