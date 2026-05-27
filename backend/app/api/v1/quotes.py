from fastapi import APIRouter, Query
from fastapi.responses import Response

from app.core.exceptions import AppError
from app.services.logo_service import logo_service
from app.services.quote_service import quote_service

router = APIRouter(prefix="/quotes", tags=["Cotações (Brapi)"])

_MAX_BATCH_TICKERS = 60


@router.get("/featured")
async def featured_quotes():
    """Principais ações para a home — fonte: Brapi."""
    return await quote_service.featured_stocks()


@router.get("/search")
async def search_quotes(
    q: str = Query(default="", min_length=2, max_length=80),
    limit: int = Query(default=20, ge=1, le=40),
):
    """Busca ações/BDRs/ETFs BR (exclui FIIs — use /v1/fiis/search)."""
    return await quote_service.search(q, limit=limit)


@router.get("/batch")
async def batch_quotes(
    tickers: str = Query(..., min_length=1, max_length=600, description="Tickers separados por vírgula"),
):
    """Até 60 tickers por requisição — fonte: Brapi."""
    symbols = [part.strip() for part in tickers.split(",") if part.strip()]
    if len(symbols) > _MAX_BATCH_TICKERS:
        raise AppError(
            f"Máximo de {_MAX_BATCH_TICKERS} tickers por requisição",
            status_code=400,
        )
    return await quote_service.get_quotes_batch(symbols)


@router.get("/market/{category_slug}")
async def list_market_quotes(
    category_slug: str,
    limit: int = Query(default=30, ge=1, le=100),
    page: int = Query(default=1, ge=1),
):
    """
    Lista por categoria do app: `acoes_br`, `bdr`, `etf`, `etf_intl`.
    FIIs: use /v1/fiis.
    """
    return await quote_service.list_by_category(category_slug, limit=limit, page=page)


@router.get("/catalog")
async def get_stock_catalog(
    category: str = Query(default="acoes_br", pattern="^(acoes_br|bdr|etf|etf_intl)$"),
):
    """Catálogo B3 cacheado — símbolos, nomes e setores para busca offline."""
    return await quote_service.get_stock_catalog(category)


@router.get("/screener")
async def screener_quotes(
    sector: str | None = Query(default=None, max_length=80),
    sort_by: str = Query(default="volume", max_length=32),
    sort_order: str = Query(default="desc", pattern="^(asc|desc)$"),
    limit: int = Query(default=50, ge=1, le=100),
    page: int = Query(default=1, ge=1),
    quote_type: str = Query(default="stock", pattern="^(stock|bdr)$", alias="type"),
    search: str | None = Query(default=None, max_length=80),
    min_dividend_yield: float | None = Query(default=None, ge=0, le=100),
    max_dividend_yield: float | None = Query(default=None, ge=0, le=100),
    min_price_earnings: float | None = Query(default=None, ge=0),
    max_price_earnings: float | None = Query(default=None, ge=0),
    min_return_on_equity: float | None = Query(default=None, ge=-100, le=200),
    max_return_on_equity: float | None = Query(default=None, ge=-100, le=200),
    min_price_to_book: float | None = Query(default=None, ge=0),
    max_price_to_book: float | None = Query(default=None, ge=0),
):
    """Screener de ações/BDRs — volume, setor, cap. e filtros fundamentalistas."""
    return await quote_service.screener(
        sector=sector,
        quote_type=quote_type,
        search=search,
        sort_by=sort_by,
        sort_order=sort_order,
        limit=limit,
        page=page,
        min_dividend_yield=min_dividend_yield,
        max_dividend_yield=max_dividend_yield,
        min_price_earnings=min_price_earnings,
        max_price_earnings=max_price_earnings,
        min_return_on_equity=min_return_on_equity,
        max_return_on_equity=max_return_on_equity,
        min_price_to_book=min_price_to_book,
        max_price_to_book=max_price_to_book,
    )


@router.get("/{ticker}/logo.png")
async def get_stock_logo_png(ticker: str):
    """Logo PNG do ativo — proxy cacheado (icones-b3)."""
    data = await logo_service.get_png(ticker)
    return Response(
        content=data,
        media_type="image/png",
        headers={"Cache-Control": "public, max-age=86400"},
    )


@router.get("/{ticker}/detail")
async def get_stock_detail(
    ticker: str,
    candle_limit: int = Query(default=252, ge=30, le=5000),
    dividend_limit: int = Query(default=120, ge=1, le=500),
):
    """Detalhe completo: cotação, gráfico, indicadores e dividendos — Brapi."""
    return await quote_service.get_stock_detail(
        ticker,
        candle_limit=candle_limit,
        dividend_limit=dividend_limit,
    )


@router.get("/{ticker}/candles")
async def get_stock_candles(
    ticker: str,
    limit: int = Query(default=252, ge=30, le=5000),
    range_: str | None = Query(
        default=None,
        alias="range",
        pattern="^(1d|2d|5d|7d|ytd|1mo|3mo|6mo|1y|5y|max)$",
        description="Período Brapi. Intraday: 1d, 5d. Diário: 1y, max…",
    ),
    interval: str = Query(
        default="1d",
        pattern="^(1m|2m|5m|15m|30m|60m|1h|1d|1wk|1mo)$",
        description="Granularidade. Intraday: 5m com range 1d/5d.",
    ),
):
    """Histórico de pregão — Brapi (diário ou intraday)."""
    return await quote_service.get_stock_candles(
        ticker,
        limit=limit,
        range_=range_,
        interval=interval,
    )


@router.get("/{ticker}/performance")
async def get_stock_performance(
    ticker: str,
    limit: int = Query(default=252, ge=30, le=5000),
    range_: str | None = Query(
        default=None,
        alias="range",
        pattern="^(ytd|1mo|3mo|6mo|1y|5y|max)$",
    ),
    benchmark: str = Query(default="^BVSP", max_length=16, description="Benchmark (padrão IBOV)"),
):
    """Retorno acumulado da ação vs benchmark (ex.: IBOV) — Brapi."""
    return await quote_service.get_stock_performance(
        ticker,
        limit=limit,
        range_=range_,
        benchmark=benchmark,
    )


@router.get("/compare")
async def compare_quotes(
    tickers: str = Query(..., min_length=1, description="Até 3 tickers separados por vírgula"),
):
    """Compara até 3 ações/BDRs — cotação e fundamentos (Brapi)."""
    symbols = [part.strip() for part in tickers.split(",") if part.strip()]
    return await quote_service.compare_stocks(symbols)


@router.get("/{ticker}/financials")
async def get_stock_financials(
    ticker: str,
    limit: int = Query(default=8, ge=1, le=20),
    period: str = Query(default="quarterly", description="quarterly ou annual"),
):
    """Demonstrações financeiras: DRE, balanço e fluxo de caixa — Brapi."""
    return await quote_service.get_stock_financials(ticker, limit=limit, period=period)


@router.get("/{ticker}/fundamentals/history")
async def get_stock_fundamental_history(
    ticker: str,
    limit: int = Query(default=12, ge=4, le=24),
):
    """Histórico trimestral de receita, margens, ROE, DY, P/L e P/VP — Brapi."""
    return await quote_service.get_stock_fundamental_history(ticker, limit=limit)


@router.get("/{ticker}")
async def get_quote(ticker: str):
    """Cotação de um ativo — fonte: Brapi."""
    return await quote_service.get_quote(ticker)
