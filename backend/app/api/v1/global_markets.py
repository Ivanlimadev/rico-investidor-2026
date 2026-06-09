from fastapi import APIRouter, Query
from fastapi.responses import Response

from app.config import settings
from app.services.global_market_service import global_market_service
from app.services.logo_service import logo_service

router = APIRouter(prefix="/global-markets", tags=["global-markets"])


@router.get("/capabilities")
async def global_market_capabilities():
    """Metadados do plano Marketstack (Free hoje, Business depois)."""
    return global_market_service.capabilities()


@router.get("")
async def list_featured_us():
    """Principais ações dos EUA — fonte: Marketstack EOD."""
    return await global_market_service.list_featured_us()


@router.get("/explore")
async def explore_global_markets(
    category: str = Query(default="stocks", pattern=r"^[a-z_]+$"),
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=30, ge=1, le=50),
    search: str | None = Query(default=None, min_length=1, max_length=32),
):
    return await global_market_service.explore(
        category=category,
        page=page,
        limit=limit,
        search=search,
    )


@router.get("/us/heatmap")
async def us_stock_heatmap(
    exchange: str = Query(default="XNAS", min_length=3, max_length=8),
    limit: int = Query(default=18, ge=1, le=24),
):
    """Mapa de calor EUA — bolsa principal (NASDAQ) por volume EOD."""
    return await global_market_service.get_us_heatmap(exchange=exchange, limit=limit)


@router.get("/us/market")
async def list_us_market(
    category: str = Query(default="stocks", pattern=r"^(stocks|reits)$"),
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=25, ge=1, le=50),
    search: str | None = Query(default=None, min_length=1, max_length=32),
):
    """Catálogo completo EUA — NASDAQ, NYSE e NYSE Arca (paginado)."""
    return await global_market_service.list_us_market(
        category=category,
        page=page,
        limit=limit,
        search=search,
    )


@router.get("/count")
async def count_us_stocks():
    total = await global_market_service.count_us_stocks()
    caps = global_market_service.capabilities()
    return {
        "total": total,
        "provider": "marketstack",
        "data_mode": caps.data_mode,
    }


@router.get("/exchanges")
async def list_world_exchanges():
    """Bolsas agrupadas por país — apenas EUA e Brasil (demais países desativados)."""
    return await global_market_service.list_world_exchanges()


@router.get("/exchanges/{mic}/market")
async def list_exchange_market(
    mic: str,
    exchange_name: str | None = Query(default=None, max_length=120),
    country_code: str | None = Query(default=None, min_length=2, max_length=3),
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=25, ge=1, le=50),
    search: str | None = Query(default=None, min_length=1, max_length=32),
):
    """Ativos de uma bolsa (MIC) com cotação EOD — paginado."""
    return await global_market_service.list_exchange_market(
        mic,
        exchange_name=exchange_name,
        country_code=country_code,
        page=page,
        limit=limit,
        search=search,
    )


@router.get("/countries/{country_code}/hub")
async def get_country_hub(country_code: str):
    """Destaques do país — principais, altas, tecnologia e mais."""
    return await global_market_service.get_country_hub(country_code)


@router.get("/countries/{country_code}/market")
async def list_country_market(
    country_code: str,
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=25, ge=1, le=50),
    search: str | None = Query(default=None, min_length=1, max_length=32),
):
    """Ativos agregados por país — todas as bolsas do país em uma listagem."""
    return await global_market_service.list_country_market(
        country_code,
        page=page,
        limit=limit,
        search=search,
    )


@router.get("/compare")
async def compare_global_stocks(
    symbols: str = Query(..., min_length=1, max_length=48, description="Tickers separados por vírgula (máx. 3)"),
):
    tickers = [part.strip() for part in symbols.split(",") if part.strip()]
    return await global_market_service.compare_stocks(tickers)


@router.get("/quotes")
async def batch_global_quotes(
    symbols: str = Query(..., min_length=1, max_length=512, description="Tickers separados por vírgula"),
    exchange: str | None = Query(default=None, min_length=3, max_length=8),
):
    """Cotações US em lote — cache curto de preço, ideal para carteira."""
    tickers = [part.strip() for part in symbols.split(",") if part.strip()]
    return await global_market_service.get_quotes_batch(tickers, exchange=exchange)


@router.get("/{symbol}/logo.png")
async def get_global_stock_logo_png(symbol: str):
    """Logo PNG de ações americanas — proxy cacheado."""
    data = await logo_service.get_us_png(symbol)
    max_age = settings.logo_http_max_age_seconds
    return Response(
        content=data,
        media_type="image/png",
        headers={"Cache-Control": f"public, max-age={max_age}, immutable, stale-while-revalidate=86400"},
    )


@router.get("/{symbol}/detail")
async def get_global_stock_detail(
    symbol: str,
    exchange: str | None = Query(default=None, min_length=3, max_length=8),
    candle_limit: int = Query(default=252, ge=30, le=1000),
    dividend_limit: int = Query(default=100, ge=1, le=500),
    split_limit: int = Query(default=50, ge=1, le=100),
    include_extras: bool = Query(default=True),
):
    """Detalhe completo Marketstack — pregão, histórico, dividendos e splits."""
    return await global_market_service.get_stock_detail(
        symbol,
        exchange=exchange,
        candle_limit=candle_limit,
        dividend_limit=dividend_limit,
        split_limit=split_limit,
        include_extras=include_extras,
    )


@router.get("/{symbol}/candles")
async def get_global_candles(
    symbol: str,
    exchange: str | None = Query(default=None, min_length=3, max_length=8),
    limit: int = Query(default=252, ge=1, le=1000),
):
    return await global_market_service.get_candles(symbol, exchange=exchange, limit=limit)


@router.get("/{symbol}/intraday")
async def get_global_intraday_candles(
    symbol: str,
    exchange: str | None = Query(default=None, min_length=3, max_length=8),
    limit: int = Query(default=500, ge=10, le=1000),
):
    """Candles intraday do dia (5min no Professional)."""
    return await global_market_service.get_intraday_candles(
        symbol,
        exchange=exchange,
        limit=limit,
    )


@router.get("/{symbol}")
async def get_global_quote(
    symbol: str,
    exchange: str | None = Query(default=None, min_length=3, max_length=8),
):
    return await global_market_service.get_quote(symbol, exchange=exchange)
