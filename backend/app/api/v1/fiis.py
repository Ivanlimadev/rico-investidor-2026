from fastapi import APIRouter, Query, Request

from app.services.fii_service import fii_service

router = APIRouter(prefix="/fiis", tags=["FIIs (Bolsai)"])


@router.get("")
async def list_fiis(
    limit: int = Query(default=500, ge=1, le=5000),
    offset: int = Query(default=0, ge=0),
):
    """Lista FIIs paginada — fonte: Bolsai."""
    return await fii_service.list_fiis(limit=limit, offset=offset)


@router.get("/search")
async def search_fiis(
    q: str = Query(default="", max_length=100),
    limit: int = Query(default=20, ge=1, le=100),
):
    """Busca FIIs por ticker ou nome (catálogo em cache)."""
    return await fii_service.search_fiis(q, limit=limit)


@router.get("/count")
async def count_fiis():
    """Total de FIIs no catálogo."""
    total = await fii_service.count_fiis()
    return {"total": total, "provider": fii_service.provider().value}


@router.get("/screener")
async def screener_fiis(request: Request):
    """Screener Pro — filtra e ordena FIIs (repassa query params à Bolsai)."""
    params = dict(request.query_params)
    return await fii_service.screen_fiis(params)


@router.get("/{ticker}/distributions")
async def get_fii_distributions(
    ticker: str,
    years: int = Query(default=5, ge=1, le=20),
):
    """Distribuições — fonte: Bolsai."""
    return await fii_service.get_distributions(ticker, years=years)


@router.get("/{ticker}/candles")
async def get_fii_candles(
    ticker: str,
    limit: int = Query(default=252, ge=1, le=5000),
    start: str | None = Query(default=None, pattern=r"^\d{4}-\d{2}-\d{2}$"),
    end: str | None = Query(default=None, pattern=r"^\d{4}-\d{2}-\d{2}$"),
):
    """Candles diários OHLC — fonte: Bolsai /stocks (pregão B3)."""
    return await fii_service.get_candles(ticker, limit=limit, start=start, end=end)


@router.get("/{ticker}/history")
async def get_fii_history(
    ticker: str,
    limit: int = Query(default=24, ge=1, le=120),
):
    """Histórico mensal — fonte: Bolsai."""
    return await fii_service.get_history(ticker, limit=limit)


@router.get("/{ticker}/tenants")
async def get_fii_tenants(ticker: str):
    """Concentração de receita por setor de inquilino — fonte: Bolsai."""
    return await fii_service.get_tenants(ticker)


@router.get("/{ticker}")
async def get_fii(ticker: str):
    """Detalhe do FII — fonte: Bolsai."""
    return await fii_service.get_fii(ticker)
