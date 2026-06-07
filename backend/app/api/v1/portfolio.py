from fastapi import APIRouter, Depends, Request

from app.core.auth_deps import get_auth_user, require_registered_user
from app.domain.portfolio.models import (
    PortfolioHoldingCreateRequest,
    PortfolioHoldingUpdateRequest,
    PortfolioHoldingsListResponse,
    PortfolioSyncRequest,
)
from app.services.portfolio_service import PortfolioService, portfolio_service

router = APIRouter(prefix="/portfolio", tags=["Carteira"])


def get_portfolio_service() -> PortfolioService:
    return portfolio_service


@router.get("/holdings", response_model=PortfolioHoldingsListResponse)
async def list_holdings(
    request: Request,
    service: PortfolioService = Depends(get_portfolio_service),
):
    user = require_registered_user(request)
    return service.list_holdings(user.id)


@router.post("/holdings", response_model=PortfolioHoldingsListResponse)
async def create_holding(
    body: PortfolioHoldingCreateRequest,
    request: Request,
    service: PortfolioService = Depends(get_portfolio_service),
):
    user = require_registered_user(request)
    service.create_holding(user.id, body)
    return service.list_holdings(user.id)


@router.put("/holdings/{holding_id}", response_model=PortfolioHoldingsListResponse)
async def update_holding(
    holding_id: str,
    body: PortfolioHoldingUpdateRequest,
    request: Request,
    service: PortfolioService = Depends(get_portfolio_service),
):
    user = require_registered_user(request)
    service.update_holding(user.id, holding_id, body)
    return service.list_holdings(user.id)


@router.delete("/holdings/{holding_id}", response_model=PortfolioHoldingsListResponse)
async def delete_holding(
    holding_id: str,
    request: Request,
    service: PortfolioService = Depends(get_portfolio_service),
):
    user = require_registered_user(request)
    service.delete_holding(user.id, holding_id)
    return service.list_holdings(user.id)


@router.post("/holdings/sync", response_model=PortfolioHoldingsListResponse)
async def sync_holdings(
    body: PortfolioSyncRequest,
    request: Request,
    service: PortfolioService = Depends(get_portfolio_service),
):
    user = require_registered_user(request)
    return service.sync_holdings(user.id, body)
