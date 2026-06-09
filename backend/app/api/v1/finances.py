from fastapi import APIRouter, Depends, Query, Request

from app.core.auth_deps import require_registered_user
from app.domain.auth.models import MessageResponse
from app.domain.finances.models import (
    ExchangeTokenRequest,
    ExchangeTokenResponse,
    FinanceBudgetResponse,
    FinanceBudgetUpsertRequest,
    FinanceBillsResponse,
    FinanceSummaryResponse,
    FinanceTransactionCreateRequest,
    FinanceTransactionResponse,
    FinanceTransactionsListResponse,
    FinanceTransactionUpdateRequest,
    LinkTokenResponse,
    PlaidAccountsListResponse,
)
from app.services.finance_service import FinanceService, finance_service

router = APIRouter(prefix="/finances", tags=["Finanças"])


def get_finance_service() -> FinanceService:
    return finance_service


@router.post("/link-token", response_model=LinkTokenResponse)
async def create_link_token(
    request: Request,
    service: FinanceService = Depends(get_finance_service),
):
    user = require_registered_user(request)
    return service.create_link_token(user.id)


@router.post("/exchange-token", response_model=ExchangeTokenResponse)
async def exchange_token(
    body: ExchangeTokenRequest,
    request: Request,
    service: FinanceService = Depends(get_finance_service),
):
    user = require_registered_user(request)
    result = service.exchange_public_token(user.id, body)
    return ExchangeTokenResponse(**result)


@router.post("/webhook")
async def plaid_webhook(
    payload: dict,
    service: FinanceService = Depends(get_finance_service),
):
    return service.handle_webhook(payload)


@router.get("/accounts", response_model=PlaidAccountsListResponse)
async def list_accounts(
    request: Request,
    service: FinanceService = Depends(get_finance_service),
):
    user = require_registered_user(request)
    return service.list_accounts(user.id)


@router.delete("/accounts/{account_id}", response_model=MessageResponse)
async def delete_account(
    account_id: str,
    request: Request,
    service: FinanceService = Depends(get_finance_service),
):
    user = require_registered_user(request)
    return service.delete_account(user.id, account_id)


@router.get("/transactions", response_model=FinanceTransactionsListResponse)
async def list_transactions(
    request: Request,
    month: str | None = Query(default=None, pattern=r"^\d{4}-\d{2}$"),
    category: str | None = None,
    limit: int = Query(default=100, ge=1, le=500),
    service: FinanceService = Depends(get_finance_service),
):
    user = require_registered_user(request)
    return service.list_transactions(user.id, month=month, category=category, limit=limit)


@router.post("/transactions", response_model=FinanceTransactionResponse)
async def create_transaction(
    body: FinanceTransactionCreateRequest,
    request: Request,
    service: FinanceService = Depends(get_finance_service),
):
    user = require_registered_user(request)
    return service.create_manual_transaction(user.id, body)


@router.patch("/transactions/{transaction_id}", response_model=FinanceTransactionResponse)
async def update_transaction(
    transaction_id: str,
    body: FinanceTransactionUpdateRequest,
    request: Request,
    service: FinanceService = Depends(get_finance_service),
):
    user = require_registered_user(request)
    return service.update_transaction(user.id, transaction_id, body)


@router.get("/summary", response_model=FinanceSummaryResponse)
async def finance_summary(
    request: Request,
    month: str | None = Query(default=None, pattern=r"^\d{4}-\d{2}$"),
    service: FinanceService = Depends(get_finance_service),
):
    user = require_registered_user(request)
    return service.get_summary(user.id, month=month)


@router.get("/budget", response_model=FinanceBudgetResponse)
async def get_budget(
    request: Request,
    month: str | None = Query(default=None, pattern=r"^\d{4}-\d{2}$"),
    service: FinanceService = Depends(get_finance_service),
):
    user = require_registered_user(request)
    return service.get_budget(user.id, month=month)


@router.put("/budget", response_model=FinanceBudgetResponse)
async def upsert_budget(
    body: FinanceBudgetUpsertRequest,
    request: Request,
    service: FinanceService = Depends(get_finance_service),
):
    user = require_registered_user(request)
    return service.upsert_budget(user.id, body)


@router.get("/bills", response_model=FinanceBillsResponse)
async def list_bills(
    request: Request,
    service: FinanceService = Depends(get_finance_service),
):
    user = require_registered_user(request)
    return service.list_bills(user.id)
