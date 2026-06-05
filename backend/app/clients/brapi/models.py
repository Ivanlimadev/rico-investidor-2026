from pydantic import BaseModel, Field

from app.domain.fii.models import FiiCandleBar, FiiDistributionPayment, FiiDistributionYearSummary


class MarketQuote(BaseModel):
    symbol: str
    name: str
    price: float
    change_percent: float
    category: str
    provider: str = "brapi"
    exchange: str | None = None
    logo_url: str | None = None
    dividend_yield_12m: float | None = None
    price_to_book: float | None = None
    # Campos EOD — preenchidos apenas pela Marketstack (ativos globais).
    open: float | None = None
    high: float | None = None
    low: float | None = None
    volume: float | None = None
    previous_close: float | None = None
    session_date: str | None = None
    split_factor: float | None = None
    dividend_amount: float | None = None
    adj_close: float | None = None
    # Últimos fechamentos EOD para mini-gráfico na lista (~24 pregões).
    sparkline: list[float] = Field(default_factory=list)


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
    dividend_yield_12m: float | None = None
    price_earnings: float | None = None
    return_on_equity: float | None = None
    price_to_book: float | None = None
    provider: str = "brapi"
    sparkline: list[float] = Field(default_factory=list)


class StockScreenerResponse(BaseModel):
    items: list[StockScreenerItem]
    count: int
    total: int | None = None
    page: int = 1
    total_pages: int | None = None
    sectors: list[str] = Field(default_factory=list)
    provider: str = "brapi"


class StockCatalogItem(BaseModel):
    symbol: str
    name: str
    category: str
    sector: str | None = None
    logo_url: str | None = None
    provider: str = "brapi"


class StockCatalogResponse(BaseModel):
    quote_type: str
    items: list[StockCatalogItem] = Field(default_factory=list)
    count: int
    total: int
    sectors: list[str] = Field(default_factory=list)
    provider: str = "brapi"


class StockMarketStats(BaseModel):
    open: float | None = None
    day_high: float | None = None
    day_low: float | None = None
    previous_close: float | None = None
    volume: float | None = None
    avg_daily_volume: float | None = None
    market_cap: float | None = None
    price_earnings: float | None = None
    earnings_per_share: float | None = None
    fifty_two_week_low: float | None = None
    fifty_two_week_high: float | None = None
    fifty_two_week_range: str | None = None
    price_range_sessions: int | None = None
    price_range_label: str | None = None
    provider: str = "brapi"


class StockCorporateAction(BaseModel):
    label: str | None = None
    factor: float | None = None
    complete_factor: str | None = None
    ex_date: str | None = None


class StockDividendEvent(BaseModel):
    label: str | None = None
    com_date: str | None = None
    ex_date: str | None = None
    payment_date: str | None = None
    value_per_share: float | None = None
    is_projected: bool = False


class StockDividendsSummary(BaseModel):
    dividend_yield_display: float | None = None
    ttm_per_share_display: float | None = None
    dividend_yield_avg_5y: float | None = None
    dividend_yield_avg_10y: float | None = None
    frequency_label: str | None = None
    avg_amount_12m: float | None = None
    payments_12m: int | None = None
    next_dividend: StockDividendEvent | None = None
    upcoming: list[StockDividendEvent] = Field(default_factory=list)


class StockDividendsResponse(BaseModel):
    ticker: str
    name: str | None = None
    count: int
    total_payments: int | None = None
    ttm_per_share: float | None = None
    dividend_yield_ttm: float | None = None
    summary: StockDividendsSummary = Field(default_factory=StockDividendsSummary)
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
    total_revenue: float | None = None
    ebitda: float | None = None
    enterprise_value: float | None = None
    enterprise_to_ebitda: float | None = None
    forward_pe: float | None = None
    gross_margin: float | None = None
    operating_margin: float | None = None
    revenue_growth: float | None = None
    total_cash: float | None = None
    total_debt: float | None = None
    current_ratio: float | None = None
    target_mean_price: float | None = None
    recommendation_key: str | None = None
    number_of_analyst_opinions: int | None = None
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
    period: str = "quarterly"
    income_statement: list[FinancialPeriod] = Field(default_factory=list)
    balance_sheet: list[FinancialPeriod] = Field(default_factory=list)
    cash_flow: list[FinancialPeriod] = Field(default_factory=list)
    value_added: list[FinancialPeriod] = Field(default_factory=list)
    provider: str = "brapi"

    def is_empty(self) -> bool:
        return not (
            self.income_statement
            or self.balance_sheet
            or self.cash_flow
            or self.value_added
        )


class PerformancePoint(BaseModel):
    trade_date: str
    ticker_return_pct: float
    benchmark_return_pct: float
    provider: str = "brapi"


class StockPerformanceResponse(BaseModel):
    ticker: str
    benchmark: str
    benchmark_label: str
    range: str
    count: int
    ticker_return_pct: float | None = None
    benchmark_return_pct: float | None = None
    points: list[PerformancePoint] = Field(default_factory=list)
    provider: str = "brapi"


class BrazilMacroResponse(BaseModel):
    selic: float | None = None
    selic_as_of: str | None = None
    ipca_12m: float | None = None
    ipca_as_of: str | None = None
    cdi: float | None = None
    cdi_as_of: str | None = None
    provider: str = "brapi"


class DictionaryField(BaseModel):
    key: str
    label: str | None = None
    description: str | None = None
    calculation: str | None = None
    category: str | None = None
    provider: str = "brapi"


class DictionaryResponse(BaseModel):
    category: str
    fields: list[DictionaryField] = Field(default_factory=list)
    count: int
    provider: str = "brapi"


class StockCompareReturnPeriod(BaseModel):
    label: str
    return_pct: float | None = None


class StockCompareDividendsSnapshot(BaseModel):
    dividend_yield_display: float | None = None
    dividend_yield_ttm: float | None = None
    ttm_per_share: float | None = None
    frequency_label: str | None = None
    payments_12m: int | None = None
    next_com_date: str | None = None
    next_payment_date: str | None = None
    next_amount: float | None = None
    provider: str | None = None


class StockCompareItem(BaseModel):
    quote: MarketQuote
    profile: StockProfile
    fundamentals: StockFundamentals
    market_stats: StockMarketStats
    dividends: StockCompareDividendsSnapshot = Field(
        default_factory=StockCompareDividendsSnapshot
    )
    returns: list[StockCompareReturnPeriod] = Field(default_factory=list)
    provider: str = "brapi"


class StockCompareResponse(BaseModel):
    items: list[StockCompareItem]
    count: int
    provider: str = "brapi"


class FundamentalHistoryPeriod(BaseModel):
    end_date: str
    total_revenue: float | None = None
    net_income: float | None = None
    ebitda: float | None = None
    free_cashflow: float | None = None
    profit_margin: float | None = None
    return_on_equity: float | None = None
    dividend_yield_12m: float | None = None
    price_earnings: float | None = None
    price_to_book: float | None = None
    provider: str = "brapi"


class StockFundamentalHistoryResponse(BaseModel):
    ticker: str
    periods: list[FundamentalHistoryPeriod] = Field(default_factory=list)
    count: int
    provider: str = "brapi"
