from __future__ import annotations

from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel, Field


class LinkTokenResponse(BaseModel):
    link_token: str


class ExchangeTokenRequest(BaseModel):
    public_token: str


class ExchangeTokenResponse(BaseModel):
    success: bool = True
    institution_name: str
    account_count: int


class PlaidAccountResponse(BaseModel):
    id: str
    name: str
    mask: str
    type: str
    subtype: str | None = None
    current_balance: float
    available_balance: float | None = None
    institution_name: str


class PlaidAccountsListResponse(BaseModel):
    items: list[PlaidAccountResponse]
    count: int


class FinanceTransactionResponse(BaseModel):
    id: str
    amount: float
    date: date
    merchant_name: str | None = None
    name: str
    category: str
    subcategory: str | None = None
    is_pending: bool = False
    is_manual: bool = False
    note: str | None = None
    account_id: str | None = None
    account_name: str | None = None


class FinanceTransactionsListResponse(BaseModel):
    items: list[FinanceTransactionResponse]
    count: int


class FinanceTransactionCreateRequest(BaseModel):
    amount: float
    date: Optional[date] = None
    merchant_name: str | None = None
    name: str
    category: str = "other"
    subcategory: str | None = None
    note: str | None = None


class FinanceTransactionUpdateRequest(BaseModel):
    category: str | None = None
    subcategory: str | None = None
    note: str | None = None


class FinanceSummaryResponse(BaseModel):
    income_mtd: float
    expenses_mtd: float
    balance: float
    vs_last_month: float = 0.0
    month: str
    updated_at: datetime | None = None


class BudgetCategoryResponse(BaseModel):
    category: str
    limit: float
    spent: float


class FinanceBudgetResponse(BaseModel):
    month: str
    mode: str = "categories"
    categories: list[BudgetCategoryResponse]


class FinanceBudgetUpsertRequest(BaseModel):
    month: str
    mode: str = "categories"
    categories: list[BudgetCategoryResponse] = Field(default_factory=list)


class RecurringBillResponse(BaseModel):
    id: str
    merchant_name: str
    amount: float
    frequency: str
    next_date: date | None = None
    category: str
    is_active: bool = True


class FinanceBillsResponse(BaseModel):
    items: list[RecurringBillResponse]
    monthly_total: float
    count: int
