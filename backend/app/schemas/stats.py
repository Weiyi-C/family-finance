from pydantic import BaseModel


class StatsSummary(BaseModel):
    total_expense: int
    total_income: int
    net: int
    count: int


class CategoryStats(BaseModel):
    category_id: int
    total: int
    count: int


class MonthlyStats(BaseModel):
    month: str
    expense: int
    income: int


class DailyStats(BaseModel):
    date: str
    total: int
    count: int


class MerchantRank(BaseModel):
    merchant: str
    total: int
    count: int


class AccountStats(BaseModel):
    account_id: int
    account_name: str
    total_expense: int
    total_income: int
    count: int
