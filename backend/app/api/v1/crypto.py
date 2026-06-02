from fastapi import APIRouter, Query
from fastapi.responses import Response

from app.config import settings
from app.domain.crypto.presets import CRYPTO_CHART_PRESETS, VALID_KLINE_INTERVALS
from app.services.crypto_service import crypto_service
from app.services.logo_service import logo_service

router = APIRouter(prefix="/crypto", tags=["crypto"])


@router.get("")
async def list_featured_crypto():
    """Principais criptomoedas em USD (USDT) — fonte: Binance."""
    return await crypto_service.list_featured()


@router.get("/explore")
async def explore_crypto(
    search: str | None = Query(default=None, min_length=1, max_length=32),
    group: str = Query(default="all", pattern=r"^[a-z_]+$"),
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=30, ge=1, le=50),
):
    """Criptomoedas paginadas com cotação — para tela Explorar."""
    return await crypto_service.explore(search=search, group=group, page=page, limit=limit)


@router.get("/count")
async def count_crypto():
    return {"total": await crypto_service.count_coins(), "provider": "binance"}


@router.get("/chart-presets")
async def crypto_chart_presets():
    return {
        "presets": [
            {"id": preset_id, "interval": values[0], "limit": values[1]}
            for preset_id, values in CRYPTO_CHART_PRESETS.items()
        ],
        "intervals": sorted(VALID_KLINE_INTERVALS),
    }


@router.get("/stream-info")
async def crypto_stream_info():
    """Metadados dos WebSockets públicos da Binance."""
    base = settings.binance_ws_base_url.rstrip("/")
    return {
        "provider": "binance",
        "currency": "USD",
        "quote_asset": "USDT",
        "stream_base": base,
        "trade_stream": "{base}/ws/{pair}@trade",
        "depth_stream": "{base}/ws/{pair}@depth10@100ms",
        "mini_ticker_stream": "{base}/stream?streams={pairs}",
        "mini_ticker_pair_suffix": "@miniTicker",
        "pair_template": "{symbol}USDT",
    }


@router.get("/movers")
async def crypto_daily_movers(limit: int = Query(default=5, ge=1, le=10)):
    """Maiores altas e baixas do dia entre pares USDT com liquidez."""
    return await crypto_service.get_daily_movers(limit=limit)


@router.get("/macro")
async def crypto_macro():
    """Macro cripto: dominância BTC, cap total, fear & greed, USDT/BRL."""
    return await crypto_service.get_macro()


@router.get("/heatmap")
async def crypto_heatmap(limit: int = Query(default=18, ge=1, le=24)):
    """Mapa de calor — top pares USDT por volume com variação 24h."""
    return await crypto_service.get_heatmap(limit=limit)


@router.get("/{symbol}/profile")
async def get_crypto_profile(symbol: str):
    """Perfil investidor: cotação, variações 7d/30d/1a, fundamentos e BRL."""
    return await crypto_service.get_investor_profile(symbol)


@router.get("/{symbol}")
async def get_crypto_quote(symbol: str):
    """Cotação 24h de uma criptomoeda."""
    return await crypto_service.get_quote(symbol)


@router.get("/{symbol}/logo.png")
async def get_crypto_logo_png(symbol: str):
    """Logo PNG de criptomoeda — proxy cacheado (CoinCap + fallback)."""
    data = await logo_service.get_crypto_png(symbol)
    max_age = settings.logo_http_max_age_seconds
    return Response(
        content=data,
        media_type="image/png",
        headers={"Cache-Control": f"public, max-age={max_age}, immutable, stale-while-revalidate=86400"},
    )


@router.get("/{symbol}/market")
async def get_crypto_market(symbol: str):
    """Snapshot: cotação + book + profundidade + trades recentes."""
    return await crypto_service.get_market_snapshot(symbol)


@router.get("/{symbol}/candles")
async def get_crypto_candles(
    symbol: str,
    interval: str = Query(default="1d", pattern=r"^[0-9]+[mhdw]$"),
    limit: int = Query(default=252, ge=1, le=1000),
    preset: str | None = Query(default=None, pattern=r"^[a-z0-9_]+$"),
):
    """OHLCV — intervalo Binance ou preset (1d, 1w, 1m, 3m, 1y, max)."""
    if preset:
        return await crypto_service.get_candles_preset(symbol, preset=preset)
    return await crypto_service.get_candles(symbol, interval=interval, limit=limit)


@router.get("/{symbol}/depth")
async def get_crypto_depth(
    symbol: str,
    limit: int = Query(default=10, ge=5, le=100),
):
    """Livro de ofertas (order book)."""
    return await crypto_service.get_order_book(symbol, limit=limit)


@router.get("/{symbol}/trades")
async def get_crypto_trades(
    symbol: str,
    limit: int = Query(default=20, ge=1, le=100),
):
    """Negócios recentes no par USDT."""
    return await crypto_service.get_recent_trades(symbol, limit=limit)


@router.get("/{symbol}/history")
async def get_crypto_history(
    symbol: str,
    limit: int = Query(default=252, ge=1, le=1000),
    interval: str = Query(default="1d", pattern=r"^[0-9]+[mhdw]$"),
):
    """Histórico (fechamento) — compatível com clientes antigos."""
    return await crypto_service.get_history(symbol, limit=limit, interval=interval)
