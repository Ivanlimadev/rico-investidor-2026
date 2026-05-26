from fastapi import APIRouter, Query

from app.services.asset_service import asset_service

router = APIRouter(prefix="/assets", tags=["Ativos (unificado)"])


@router.get("/{ticker}")
async def get_asset_detail(
    ticker: str,
    candle_limit: int = Query(default=252, ge=30, le=5000),
    dividend_limit: int = Query(default=120, ge=1, le=500),
):
    """
    Detalhe unificado por ticker.

    FIIs → Bolsai (+ enriquecimento Brapi quando disponível).
    Ações, BDRs e ETFs → Brapi.
    """
    return await asset_service.get_detail(
        ticker,
        candle_limit=candle_limit,
        dividend_limit=dividend_limit,
    )
