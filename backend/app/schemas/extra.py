from datetime import date, datetime
from pydantic import BaseModel, Field


class AliasCreate(BaseModel):
    original_name: str = Field(..., min_length=1, max_length=200)
    alias_name: str = Field(..., min_length=1, max_length=100)
    category_id: int | None = None
    sub_category_id: int | None = None
    platform_id: int | None = None


class AliasUpdate(BaseModel):
    alias_name: str | None = Field(None, min_length=1, max_length=100)
    category_id: int | None = None
    sub_category_id: int | None = None
    platform_id: int | None = None


class AliasResponse(BaseModel):
    id: int
    family_id: int | None
    original_name: str
    alias_name: str
    category_id: int | None
    sub_category_id: int | None
    platform_id: int | None
    hit_count: int
    is_active: bool

    model_config = {"from_attributes": True}


class RuleCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    conditions: dict
    actions: dict
    stage: str = "classify"
    priority: int = 0


class RuleUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=100)
    conditions: dict | None = None
    actions: dict | None = None
    stage: str | None = None
    priority: int | None = None
    is_active: bool | None = None


class RuleResponse(BaseModel):
    id: int
    family_id: int | None
    name: str
    conditions: dict
    actions: dict
    stage: str
    priority: int
    is_active: bool
    hit_count: int

    model_config = {"from_attributes": True}


class RuleTestRequest(BaseModel):
    conditions: dict
    test_data: dict


class BackupConfigCreate(BaseModel):
    backup_type: str = Field(..., max_length=30)
    schedule: str = Field(..., max_length=50)
    target: str = Field(..., max_length=30)
    target_config: dict | None = None
    retention_days: int = 30
    max_backups: int = 10


class BackupConfigResponse(BaseModel):
    id: int
    family_id: int
    backup_type: str
    schedule: str
    is_enabled: bool
    target: str
    target_config: dict | None
    retention_days: int
    max_backups: int

    model_config = {"from_attributes": True}


class BackupLogResponse(BaseModel):
    id: int
    backup_type: str
    backup_target: str
    file_path: str | None
    file_size: int | None
    file_format: str | None
    table_counts: dict | None
    status: str
    error_message: str | None
    duration_ms: int | None
    created_at: datetime | None

    model_config = {"from_attributes": True}


class CreditBillResponse(BaseModel):
    id: int
    account_id: int
    family_id: int
    bill_year: int
    bill_month: int
    billing_date: date
    due_date: date
    total_amount: int
    paid_amount: int
    min_payment: int
    status: str

    model_config = {"from_attributes": True}


class CreditBillPayRequest(BaseModel):
    amount: int = Field(..., gt=0)


class ImportCreate(BaseModel):
    book_id: int
    source: str = Field(..., max_length=30)
    file_format: str | None = None
    items: list[dict] = []


class ImportItemResponse(BaseModel):
    id: int
    import_id: int
    raw_data: dict
    parsed_amount: int | None
    parsed_time: datetime | None
    parsed_merchant: str | None
    parsed_category: str | None
    matched_txn_id: int | None
    action: str

    model_config = {"from_attributes": True}


class ImportResponse(BaseModel):
    id: int
    family_id: int
    book_id: int
    source: str
    file_url: str | None
    file_format: str | None
    status: str
    total_rows: int
    parsed_count: int
    matched_count: int
    new_count: int

    model_config = {"from_attributes": True}


class SyncPullRequest(BaseModel):
    client_id: str
    last_seq: int = 0
    limit: int = 100


class SyncPushRequest(BaseModel):
    client_id: str
    changes: list[dict]


class SyncResponse(BaseModel):
    changes: list[dict]
    current_seq: int
    has_more: bool
