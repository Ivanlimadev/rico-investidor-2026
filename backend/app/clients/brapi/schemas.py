from __future__ import annotations

from typing import Any

from pydantic import BaseModel, ConfigDict, Field


class BrapiModel(BaseModel):
    """Modelo wire da Brapi — campos extras preservados para módulos dinâmicos."""

    model_config = ConfigDict(extra="allow", populate_by_name=True)


# --- /quote ---


class BrapiQuoteResult(BrapiModel):
    symbol: str | None = None
    longName: str | None = None
    shortName: str | None = None
    regularMarketPrice: float | None = None
    regularMarketChangePercent: float | None = None
    type: str | None = None
    quoteType: str | None = None
    logourl: str | None = None
    priceEarnings: float | None = None
    earningsPerShare: float | None = None
    historicalDataPrice: list[dict[str, Any]] | None = None
    dividendsData: dict[str, Any] | None = None
    summaryProfile: dict[str, Any] | None = None
    financialData: dict[str, Any] | None = None
    defaultKeyStatistics: dict[str, Any] | None = None


class BrapiQuoteResponse(BrapiModel):
    results: list[BrapiQuoteResult] | None = None


# --- /quote/list ---


class BrapiListStock(BrapiModel):
    stock: str | None = None
    name: str | None = None
    close: float | None = None
    change: float | None = None
    type: str | None = None
    sector: str | None = None
    volume: float | None = None
    market_cap: float | None = None
    logo: str | None = None


class BrapiQuoteListResponse(BrapiModel):
    stocks: list[BrapiListStock] | None = None
    totalCount: int | None = None
    currentPage: int | None = None
    totalPages: int | None = None
    hasNextPage: bool | None = None
    availableSectors: list[str] | None = None


# --- v2 FII ---


class BrapiFiiIndicators(BrapiModel):
    symbol: str | None = None
    name: str | None = None
    price: float | None = None
    navPerShare: float | None = None
    priceToNav: float | None = None
    dividendYield12m: float | None = None
    equity: float | None = None
    sharesOutstanding: float | None = None
    totalInvestors: float | None = None
    segmentoAtuacao: str | None = None
    segmentType: str | None = None
    tipoGestao: str | None = None
    administratorName: str | None = None
    administratorCnpj: str | None = None
    administratorWebsite: str | None = None
    administratorEmail: str | None = None
    mandate: str | None = None
    asOfDate: str | None = None


class BrapiFiiIndicatorsResponse(BrapiModel):
    fiis: list[BrapiFiiIndicators] | None = None


class BrapiFiiReport(BrapiModel):
    symbol: str | None = None
    referenceDate: str | None = None
    totalAssets: float | None = None
    realEstateAssets: float | None = None
    fiiHoldings: float | None = None
    cri: float | None = None
    lci: float | None = None
    cash: float | None = None
    adminFeeRate: float | None = None


class BrapiFiiReportsResponse(BrapiModel):
    reports: list[BrapiFiiReport] | None = None


class BrapiFiiDividend(BrapiModel):
    symbol: str | None = None
    rate: float | None = None
    lastDatePrior: str | None = None
    paymentDate: str | None = None


class BrapiFiiDividendsResponse(BrapiModel):
    dividends: list[BrapiFiiDividend] | None = None


class BrapiFiiHistoryEntry(BrapiModel):
    symbol: str | None = None
    referenceDate: str | None = None
    price: float | None = None
    navPerShare: float | None = None
    priceToNav: float | None = None
    dividendYield1m: float | None = None
    equity: float | None = None
    totalInvestors: float | None = None


class BrapiFiiHistoryResponse(BrapiModel):
    history: list[BrapiFiiHistoryEntry] | None = None


class BrapiFiiHistoricalSeries(BrapiModel):
    symbol: str | None = None
    historicalDataPrice: list[dict[str, Any]] | None = None


class BrapiFiiHistoricalResponse(BrapiModel):
    fiis: list[BrapiFiiHistoricalSeries] | None = None


# --- macro / dictionary ---


class BrapiMacroPoint(BrapiModel):
    value: float | None = None
    date: str | None = None


class BrapiPrimeRateResponse(BrapiModel):
    prime_rate: list[BrapiMacroPoint] | None = Field(default=None, alias="prime-rate")


class BrapiInflationResponse(BrapiModel):
    inflation: list[BrapiMacroPoint] | None = None


class BrapiCurrencyQuote(BrapiModel):
    fromCurrency: str | None = None
    toCurrency: str | None = None
    name: str | None = None
    high: str | None = None
    low: str | None = None
    bidVariation: str | None = None
    percentageChange: str | None = None
    bidPrice: str | None = None
    askPrice: str | None = None
    updatedAtTimestamp: str | None = None
    updatedAtDate: str | None = None


class BrapiCurrencyRatesResponse(BrapiModel):
    currency: list[BrapiCurrencyQuote] | None = None


class BrapiCurrencyAvailableItem(BrapiModel):
    name: str | None = None
    currency: str | None = None


class BrapiCurrencyAvailableResponse(BrapiModel):
    currencies: list[BrapiCurrencyAvailableItem] | None = None


class BrapiCurrencyHistoryPoint(BrapiModel):
    date: str | None = None
    value: float | None = None


class BrapiCurrencyHistoricalPairResult(BrapiModel):
    pair: str | None = None
    fromCurrency: str | None = None
    toCurrency: str | None = None
    observations: list[BrapiCurrencyHistoryPoint] | None = None


class BrapiCurrencyHistoricalResponse(BrapiModel):
    results: list[BrapiCurrencyHistoricalPairResult] | None = None


class BrapiTreasuryRateInfo(BrapiModel):
    rateType: str | None = None
    rateUnit: str | None = None
    description: str | None = None


class BrapiTreasuryQuote(BrapiModel):
    symbol: str | None = None
    bondType: str | None = None
    indexer: str | None = None
    couponType: str | None = None
    maturityDate: str | None = None
    durationDays: int | None = None
    baseDate: str | None = None
    buyRate: float | None = None
    sellRate: float | None = None
    buyPrice: float | None = None
    sellPrice: float | None = None
    basePrice: float | None = None
    rateInfo: BrapiTreasuryRateInfo | None = None


class BrapiTreasuryPagination(BrapiModel):
    page: int | None = None
    limit: int | None = None
    totalItems: int | None = None
    totalPages: int | None = None
    hasNextPage: bool | None = None


class BrapiTreasuryListResponse(BrapiModel):
    results: list[BrapiTreasuryQuote] | None = None
    pagination: BrapiTreasuryPagination | None = None


class BrapiTreasuryIndicatorsResponse(BrapiModel):
    results: list[BrapiTreasuryQuote] | None = None


class BrapiTreasuryHistoryPoint(BrapiModel):
    baseDate: str | None = None
    buyRate: float | None = None
    sellRate: float | None = None
    buyPrice: float | None = None
    sellPrice: float | None = None
    basePrice: float | None = None


class BrapiTreasuryHistorySeries(BrapiModel):
    symbol: str | None = None
    bondType: str | None = None
    indexer: str | None = None
    couponType: str | None = None
    maturityDate: str | None = None
    rateInfo: BrapiTreasuryRateInfo | None = None
    history: list[BrapiTreasuryHistoryPoint] | None = None


class BrapiTreasuryHistoricalResponse(BrapiModel):
    results: list[BrapiTreasuryHistorySeries] | None = None


class BrapiDictionaryField(BrapiModel):
    key: str | None = None
    label: str | None = None
    description: str | None = None
    calculation: str | None = None
    category: str | None = None


class BrapiDictionaryResponse(BrapiModel):
    fields: list[BrapiDictionaryField] | None = None
