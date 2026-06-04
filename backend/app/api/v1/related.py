from fastapi import APIRouter, Query

from app.services.related_assets_service import related_assets_service

router = APIRouter(prefix="/related", tags=["Ativos relacionados"])


@router.get("/{ticker}")
async def list_related_assets(
    ticker: str,
    market: str = Query(
        ...,
        description="acoes_br | bdr | etf | stocks | reits | cripto",
        pattern=r"^[a-z_]+$",
    ),
    sector: str | None = Query(default=None, max_length=80),
    industry: str | None = Query(default=None, max_length=80),
    limit: int = Query(default=6, ge=1, le=8),
):
    """Pares temáticos (mesmo setor/grupo) com cotação ao vivo."""
    return await related_assets_service.list_related(
        ticker,
        market=market,
        sector=sector,
        industry=industry,
        limit=limit,
    )
