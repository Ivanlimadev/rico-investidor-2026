from fastapi import APIRouter, Query

from app.services.quote_service import quote_service

router = APIRouter(prefix="/quotes", tags=["Cotações (Brapi)"])


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
    tickers: str = Query(..., min_length=1, description="Tickers separados por vírgula"),
):
    """Até 20 tickers por requisição — fonte: Brapi."""
    symbols = [part.strip() for part in tickers.split(",") if part.strip()]
    return await quote_service.get_quotes_batch(symbols)


@router.get("/market/{category_slug}")
async def list_market_quotes(
    category_slug: str,
    limit: int = Query(default=30, ge=1, le=100),
    page: int = Query(default=1, ge=1),
):
    """
    Lista por categoria do app: `acoes_br`, `bdr`, `etf`.
    FIIs: use /v1/fiis.
    """
    return await quote_service.list_by_category(category_slug, limit=limit, page=page)


@router.get("/screener")
async def screener_quotes(
    sector: str | None = Query(default=None, max_length=80),
    sort_by: str = Query(default="volume", max_length=32),
    sort_order: str = Query(default="desc", pattern="^(asc|desc)$"),
    limit: int = Query(default=50, ge=1, le=100),
    page: int = Query(default=1, ge=1),
    quote_type: str = Query(default="stock", pattern="^(stock|bdr)$", alias="type"),
    search: str | None = Query(default=None, max_length=80),
):
    """Screener de ações/BDRs — volume, variação, setor e cap. de mercado (Brapi)."""
    return await quote_service.screener(
        sector=sector,
        quote_type=quote_type,
        search=search,
        sort_by=sort_by,
        sort_order=sort_order,
        limit=limit,
        page=page,
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
        pattern="^(ytd|1mo|3mo|6mo|1y|5y|max)$",
        description="Período Brapi (preferencial). Ex.: ytd, 1y, max",
    ),
):
    """Histórico de pregão — Brapi."""
    return await quote_service.get_stock_candles(ticker, limit=limit, range_=range_)


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
):
    """Demonstrações trimestrais: DRE, balanço e fluxo de caixa — Brapi."""
    return await quote_service.get_stock_financials(ticker, limit=limit)


@router.get("/{ticker}")
async def get_quote(ticker: str):
    """Cotação de um ativo — fonte: Brapi."""
    return await quote_service.get_quote(ticker)
