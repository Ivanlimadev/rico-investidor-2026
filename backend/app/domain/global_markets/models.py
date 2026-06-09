from datetime import UTC, datetime

from pydantic import BaseModel, Field

from app.clients.brapi.models import MarketQuote, MarketQuoteBatchResponse, MarketQuoteListResponse
from app.clients.brapi.models import StockFundamentals, StockMarketStats


class GlobalMarketCapabilitiesResponse(BaseModel):
    plan: str
    data_mode: str
    max_history_days: int
    realtime_enabled: bool
    fundamentals_enabled: bool
    monthly_request_budget: int | None = None
    intraday_interval: str | None = None
    refresh_seconds: int | None = None
    bulk_refresh_seconds: int | None = None
    api_configured: bool = False
    provider: str = "marketstack"
    enabled_country_codes: list[str] = Field(default_factory=lambda: ["US", "BR"])
    global_markets_expanded: bool = False
    us_market_status: str = "closed"
    us_market_open: bool = False
    us_market_label: str = "Mercado fechado"
    us_market_timezone: str = "America/New_York"
    us_market_holiday: bool = False
    intraday_delay_minutes: int | None = None


class ExchangeInfo(BaseModel):
    mic: str
    name: str
    country: str | None = None
    country_code: str | None = None
    city: str | None = None
    website: str | None = None
    timezone: str | None = None
    ticker_count: int | None = None


class CountryExchangesGroup(BaseModel):
    country_code: str
    country_name: str
    exchanges: list[ExchangeInfo] = Field(default_factory=list)
    exchange_count: int = 0


class WorldExchangesResponse(BaseModel):
    priority_countries: list[CountryExchangesGroup] = Field(default_factory=list)
    other_countries: list[CountryExchangesGroup] = Field(default_factory=list)
    total_exchanges: int = 0
    total_countries: int = 0
    provider: str = "marketstack"
    data_mode: str = "eod"
    generated_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class GlobalStockCandle(BaseModel):
    date: str
    open: float | None = None
    high: float | None = None
    low: float | None = None
    close: float
    adj_close: float | None = None
    volume: float | None = None


class GlobalStockCandlesResponse(BaseModel):
    symbol: str
    exchange: str | None = None
    candles: list[GlobalStockCandle] = Field(default_factory=list)
    count: int = 0
    history_limited: bool = False
    max_history_days: int
    data_mode: str = "eod"
    provider: str = "marketstack"


class GlobalStockIntradayCandlesResponse(BaseModel):
    symbol: str
    exchange: str | None = None
    candles: list[GlobalStockCandle] = Field(default_factory=list)
    count: int = 0
    interval: str = "5min"
    data_mode: str = "realtime"
    provider: str = "marketstack"


class GlobalStockExploreResponse(BaseModel):
    items: list[MarketQuote]
    count: int
    total: int
    page: int = 1
    category: str
    provider: str = "marketstack"
    data_mode: str = "eod"


class ExchangeMarketListResponse(BaseModel):
    exchange_mic: str
    exchange_name: str | None = None
    country_code: str | None = None
    items: list[MarketQuote] = Field(default_factory=list)
    count: int = 0
    total: int | None = None
    page: int = 1
    limit: int = 25
    provider: str = "marketstack"
    data_mode: str = "eod"


class CountryHubSection(BaseModel):
    id: str
    title: str
    subtitle: str | None = None
    items: list[MarketQuote] = Field(default_factory=list)
    count: int = 0


class CountryHubResponse(BaseModel):
    country_code: str
    country_name: str
    sections: list[CountryHubSection] = Field(default_factory=list)
    total_market: int | None = None
    exchange_count: int = 0
    provider: str = "marketstack"
    data_mode: str = "eod"


class GlobalStockTickerInfo(BaseModel):
    symbol: str
    name: str
    country: str | None = None
    has_eod: bool = True
    has_intraday: bool = False
    exchange_mic: str | None = None
    exchange_name: str | None = None
    exchange_acronym: str | None = None
    exchange_city: str | None = None
    exchange_country_code: str | None = None
    exchange_website: str | None = None
    isin: str | None = None
    cusip: str | None = None


class GlobalStockCompanyProfile(BaseModel):
    symbol: str
    name: str
    country: str | None = None
    exchange_mic: str | None = None
    exchange_name: str | None = None
    exchange_acronym: str | None = None
    exchange_city: str | None = None
    exchange_country_code: str | None = None
    exchange_website: str | None = None
    has_eod: bool = True
    has_intraday: bool = False
    isin: str | None = None
    cusip: str | None = None
    sector: str | None = None
    industry: str | None = None
    summary: str | None = None
    website: str | None = None
    employees: int | None = None


class GlobalStockDividend(BaseModel):
    date: str
    amount: float
    ex_date: str | None = None
    com_date: str | None = None
    record_date: str | None = None
    payment_date: str | None = None
    declaration_date: str | None = None
    frequency: str | None = None
    dividend_type: str = "Dividendo"
    is_projected: bool = False


class GlobalStockDividendsSummary(BaseModel):
    ttm_per_share: float | None = None
    dividend_yield_ttm: float | None = None
    payments_12m: int = 0
    annual_totals: list[dict[str, float | int]] = Field(default_factory=list)
    upcoming: list[GlobalStockDividend] = Field(default_factory=list)
    next_dividend: GlobalStockDividend | None = None
    frequency_label: str | None = None
    avg_amount_12m: float | None = None
    total_payments: int = 0


class GlobalStockReturnPeriod(BaseModel):
    label: str
    months_back: int
    return_pct: float | None = None


class GlobalStockSplit(BaseModel):
    date: str
    split_factor: float


class GlobalStockDetailResponse(BaseModel):
    quote: MarketQuote
    ticker: GlobalStockTickerInfo
    company: GlobalStockCompanyProfile
    candles: list[GlobalStockCandle] = Field(default_factory=list)
    candles_count: int = 0
    dividends: list[GlobalStockDividend] = Field(default_factory=list)
    dividends_total: int = 0
    dividends_summary: GlobalStockDividendsSummary = Field(default_factory=GlobalStockDividendsSummary)
    returns: list[GlobalStockReturnPeriod] = Field(default_factory=list)
    splits: list[GlobalStockSplit] = Field(default_factory=list)
    splits_total: int = 0
    fundamentals: StockFundamentals = Field(default_factory=lambda: StockFundamentals(provider="marketstack"))
    market_stats: StockMarketStats = Field(default_factory=lambda: StockMarketStats(provider="marketstack"))
    plan: str = "basic"
    data_mode: str = "eod"
    max_history_days: int = 365
    history_limited: bool = False
    realtime_enabled: bool = False
    intraday_interval: str | None = None
    refresh_seconds: int | None = None
    provider: str = "marketstack"
