from pydantic import BaseModel, Field

from app.clients.bolsai.models import FiiCandleBar, FiiDistributionPayment, FiiDistributionYearSummary


class MarketQuote(BaseModel):
    symbol: str
    name: str
    price: float
    change_percent: float
    category: str
    provider: str = "brapi"


class MarketQuoteListResponse(BaseModel):
    items: list[MarketQuote]
    count: int
    provider: str = "brapi"


class MarketQuoteBatchResponse(BaseModel):
    items: list[MarketQuote]
    count: int
    provider: str = "brapi"


class StockScreenerItem(BaseModel):
    symbol: str
    name: str
    price: float
    change_percent: float
    category: str
    sector: str | None = None
    market_cap: float | None = None
    volume: float | None = None
    logo_url: str | None = None
    provider: str = "brapi"


class StockScreenerResponse(BaseModel):
    items: list[StockScreenerItem]
    count: int
    total: int | None = None
    page: int = 1
    total_pages: int | None = None
    sectors: list[str] = Field(default_factory=list)
    provider: str = "brapi"


class StockMarketStats(BaseModel):
    open: float | None = None
    day_high: float | None = None
    day_low: float | None = None
    previous_close: float | None = None
    volume: float | None = None
    market_cap: float | None = None
    price_earnings: float | None = None
    earnings_per_share: float | None = None
    fifty_two_week_low: float | None = None
    fifty_two_week_high: float | None = None
    fifty_two_week_range: str | None = None
    provider: str = "brapi"


class StockCorporateAction(BaseModel):
    label: str | None = None
    factor: float | None = None
    complete_factor: str | None = None
    ex_date: str | None = None


class StockDividendsResponse(BaseModel):
    ticker: str
    count: int
    total_payments: int | None = None
    ttm_per_share: float | None = None
    annual_summary: list[FiiDistributionYearSummary] = Field(default_factory=list)
    payments: list[FiiDistributionPayment] = Field(default_factory=list)
    corporate_actions: list[StockCorporateAction] = Field(default_factory=list)
    provider: str = "brapi"


class StockProfile(BaseModel):
    sector: str | None = None
    industry: str | None = None
    website: str | None = None
    summary: str | None = None
    employees: int | None = None
    country: str | None = None
    logo_url: str | None = None
    provider: str = "brapi"


class StockFundamentals(BaseModel):
    dividend_yield_12m: float | None = None
    price_earnings: float | None = None
    price_to_book: float | None = None
    return_on_equity: float | None = None
    return_on_assets: float | None = None
    profit_margin: float | None = None
    debt_to_equity: float | None = None
    payout_ratio: float | None = None
    beta: float | None = None
    book_value_per_share: float | None = None
    earnings_per_share: float | None = None
    free_cashflow: float | None = None
    earnings_growth: float | None = None
    provider: str = "brapi"


class StockQuoteDetailResponse(BaseModel):
    quote: MarketQuote
    market_stats: StockMarketStats
    profile: StockProfile
    fundamentals: StockFundamentals
    candles: list[FiiCandleBar] = Field(default_factory=list)
    dividends: StockDividendsResponse
    provider: str = "brapi"


class FinancialLine(BaseModel):
    key: str
    label: str
    value: float | None = None


class FinancialPeriod(BaseModel):
    end_date: str
    lines: list[FinancialLine] = Field(default_factory=list)


class StockFinancialsResponse(BaseModel):
    ticker: str
    income_statement: list[FinancialPeriod] = Field(default_factory=list)
    balance_sheet: list[FinancialPeriod] = Field(default_factory=list)
    cash_flow: list[FinancialPeriod] = Field(default_factory=list)
    provider: str = "brapi"


class StockCompareItem(BaseModel):
    quote: MarketQuote
    profile: StockProfile
    fundamentals: StockFundamentals
    market_stats: StockMarketStats
    provider: str = "brapi"


class StockCompareResponse(BaseModel):
    items: list[StockCompareItem]
    count: int
    provider: str = "brapi"
