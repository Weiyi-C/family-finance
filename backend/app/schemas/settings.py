from datetime import time

from pydantic import BaseModel


class SettingsResponse(BaseModel):
    id: int
    user_id: int
    default_currency: str
    month_start_day: int
    theme: str
    language: str
    date_format: str
    number_format: str
    default_book_id: int | None
    quick_entry_mode: str
    confirm_before_save: bool
    notify_budget_alert: bool
    notify_recurring: bool
    notify_sync: bool
    quiet_hours_start: time | None
    quiet_hours_end: time | None
    auto_sync: bool
    sync_on_wifi_only: bool
    settings_json: dict | None

    model_config = {"from_attributes": True}


class SettingsUpdate(BaseModel):
    default_currency: str | None = None
    month_start_day: int | None = None
    theme: str | None = None
    language: str | None = None
    date_format: str | None = None
    number_format: str | None = None
    default_book_id: int | None = None
    quick_entry_mode: str | None = None
    confirm_before_save: bool | None = None
    notify_budget_alert: bool | None = None
    notify_recurring: bool | None = None
    notify_sync: bool | None = None
    quiet_hours_start: time | None = None
    quiet_hours_end: time | None = None
    auto_sync: bool | None = None
    sync_on_wifi_only: bool | None = None
    settings_json: dict | None = None
