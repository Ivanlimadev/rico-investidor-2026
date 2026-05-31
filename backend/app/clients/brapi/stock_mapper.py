from __future__ import annotations

from collections import defaultdict
from datetime import UTC, datetime

from app.domain.fii.models import (
    FiiCandleBar,
    FiiCandlesResponse,
    FiiDistributionPayment,
    FiiDistributionYearSummary,
)
from app.clients.brapi.models import (
    FinancialLine,
    FinancialPeriod,
    FundamentalHistoryPeriod,
    MarketQuote,
    StockCorporateAction,
    StockDividendsResponse,
    StockFinancialsResponse,
    StockFundamentalHistoryResponse,
    StockFundamentals,
    StockMarketStats,
    StockPerformanceResponse,
    PerformancePoint,
    StockProfile,
    StockCompareItem,
    StockScreenerItem,
    StockScreenerResponse,
    StockCatalogItem,
    StockCatalogResponse,
)

STOCK_DETAIL_MODULES = "summaryProfile,financialData,defaultKeyStatistics"
STOCK_FINANCIALS_MODULES_QUARTERLY = (
    "incomeStatementHistoryQuarterly,balanceSheetHistoryQuarterly,cashflowHistoryQuarterly"
)
STOCK_FINANCIALS_MODULES_ANNUAL = (
    "incomeStatementHistory,balanceSheetHistory,cashflowHistory"
)
STOCK_DVA_MODULES_QUARTERLY = "valueAddedHistoryQuarterly"
STOCK_DVA_MODULES_ANNUAL = "valueAddedHistory"
STOCK_FINANCIALS_MODULES = STOCK_FINANCIALS_MODULES_QUARTERLY
VALID_FINANCIAL_PERIODS = frozenset({"quarterly", "annual"})
DEFAULT_STOCK_BENCHMARK = "^BVSP"
BENCHMARK_LABELS = {
    "^BVSP": "IBOV",
    "BOVA11": "BOVA11",
}
STOCK_FUNDAMENTALS_HISTORY_MODULES = (
    "financialDataHistoryQuarterly,defaultKeyStatisticsHistoryQuarterly"
)
STOCK_SCREENER_MODULES = "defaultKeyStatistics,financialData"
SCREENER_FUNDAMENTAL_SORT = frozenset(
    {"dividend_yield", "price_earnings", "return_on_equity", "price_to_book"}
)
VALID_SORT_BY = frozenset({"name", "close", "change", "change_abs", "volume", "market_cap_basic"})
from app.domain.quotes.category_map import category_to_slug, infer_category
from app.providers.registry import AssetClass


def normalize_sort_by(sort_by: str) -> str:
    normalized = sort_by.strip().lower()
    if normalized in {"market_cap", "market_cap_basic"}:
        return "market_cap_basic"
    if normalized in VALID_SORT_BY:
        return normalized
    return "volume"


def map_catalog_item(item: dict, *, target_class: AssetClass | None = None) -> StockCatalogItem | None:
    symbol = str(item.get("stock") or "").upper().strip()
    if not symbol:
        return None

    asset_class = infer_category(symbol, item.get("type"))
    if asset_class == AssetClass.FII:
        return None
    if target_class is not None and asset_class != target_class:
        return None

    return StockCatalogItem(
        symbol=symbol,
        name=item.get("name") or symbol,
        category=category_to_slug(asset_class),
        sector=item.get("sector"),
        logo_url=item.get("logo"),
    )


def map_list_market_quote(item: dict) -> MarketQuote:
    symbol = str(item["stock"]).upper()
    name = item.get("name") or symbol
    price = float(item.get("close") or 0)
    change = float(item.get("change") or 0)
    asset_class = infer_category(symbol, item.get("type"))
    return MarketQuote(
        symbol=symbol,
        name=name,
        price=price,
        change_percent=change,
        category=category_to_slug(asset_class),
    )


def map_screener_item(item: dict) -> StockScreenerItem:
    symbol = str(item["stock"]).upper()
    name = item.get("name") or symbol
    price = float(item.get("close") or 0)
    change = float(item.get("change") or 0)
    asset_class = infer_category(symbol, item.get("type"))
    volume = item.get("volume")
    market_cap = item.get("market_cap")

    return StockScreenerItem(
        symbol=symbol,
        name=name,
        price=price,
        change_percent=change,
        category=category_to_slug(asset_class),
        sector=item.get("sector"),
        market_cap=float(market_cap) if market_cap is not None else None,
        volume=float(volume) if volume is not None else None,
        logo_url=resolve_logo_url(symbol, item.get("logo")),
    )


def _normalize_date(value: str | None) -> str | None:
    if not value:
        return None
    return value.split("T", 1)[0].split(" ", 1)[0]


VALID_CANDLE_RANGES = frozenset({"1d", "2d", "5d", "7d", "ytd", "1mo", "3mo", "6mo", "1y", "5y", "max"})
VALID_CANDLE_INTERVALS = frozenset({"1m", "2m", "5m", "15m", "30m", "60m", "90m", "1h", "1d", "1wk", "1mo"})
INTRADAY_INTERVALS = frozenset({"1m", "2m", "5m", "15m", "30m", "60m", "90m", "1h"})
DEFAULT_INTRADAY_INTERVAL = "5m"


def limit_to_range(limit: int) -> str:
    if limit <= 30:
        return "1mo"
    if limit <= 66:
        return "3mo"
    if limit <= 132:
        return "6mo"
    if limit <= 252:
        return "1y"
    if limit <= 1260:
        return "5y"
    return "max"


def normalize_candle_range(range_: str | None, *, limit: int) -> str:
    if range_:
        normalized = range_.strip().lower()
        if normalized in VALID_CANDLE_RANGES:
            return normalized
    return limit_to_range(limit)


def normalize_candle_interval(interval: str | None) -> str:
    if interval:
        normalized = interval.strip().lower()
        if normalized in VALID_CANDLE_INTERVALS:
            return normalized
    return "1d"


def is_intraday_interval(interval: str) -> bool:
    return normalize_candle_interval(interval) in INTRADAY_INTERVALS


def b3_icon_png_url(symbol: str) -> str:
    return (
        "https://raw.githubusercontent.com/thefintz/icones-b3/main/icones/"
        f"{symbol.upper().strip()}.png"
    )


def brapi_icon_svg_url(symbol: str) -> str:
    return f"https://icons.brapi.dev/icons/{symbol.upper().strip()}.svg"


def resolve_logo_url(symbol: str, *candidates: str | None) -> str:
    for value in candidates:
        if value and str(value).strip():
            cleaned = str(value).strip()
            if not cleaned.lower().endswith(".svg"):
                return cleaned
    return b3_icon_png_url(symbol)


def map_market_quote(item: dict) -> MarketQuote:
    symbol = str(item["symbol"]).upper()
    name = item.get("longName") or item.get("shortName") or symbol
    price = float(item.get("regularMarketPrice") or 0)
    change = float(item.get("regularMarketChangePercent") or 0)
    asset_class = infer_category(symbol, item.get("type") or item.get("quoteType"))
    return MarketQuote(
        symbol=symbol,
        name=name,
        price=price,
        change_percent=change,
        category=category_to_slug(asset_class),
        logo_url=resolve_logo_url(symbol, item.get("logourl")),
    )


def map_enriched_market_quote(item: dict) -> MarketQuote:
    fundamentals = map_stock_fundamentals(item)
    profile = map_stock_profile(item)
    return map_market_quote(item).model_copy(
        update={
            "logo_url": resolve_logo_url(item.get("symbol", ""), profile.logo_url, item.get("logourl")),
            "dividend_yield_12m": fundamentals.dividend_yield_12m,
            "price_to_book": fundamentals.price_to_book,
        }
    )


def _as_pct(value: float | None) -> float | None:
    if value is None:
        return None
    if abs(value) <= 1:
        return round(value * 100, 2)
    return round(float(value), 2)


def _pick_float(*values: float | None) -> float | None:
    for value in values:
        if value is not None:
            return float(value)
    return None


def map_stock_profile(item: dict) -> StockProfile:
    profile = item.get("summaryProfile") or {}
    employees = profile.get("fullTimeEmployees")
    return StockProfile(
        sector=profile.get("sector"),
        industry=profile.get("industry"),
        website=profile.get("website"),
        summary=profile.get("longBusinessSummary"),
        employees=int(employees) if employees is not None else None,
        country=profile.get("country"),
        logo_url=item.get("logourl"),
    )


def normalize_financial_period(period: str | None) -> str:
    normalized = (period or "quarterly").strip().lower()
    if normalized in VALID_FINANCIAL_PERIODS:
        return normalized
    return "quarterly"


def financials_modules_for_period(period: str) -> str:
    normalized = normalize_financial_period(period)
    if normalized == "annual":
        return f"{STOCK_FINANCIALS_MODULES_ANNUAL},{STOCK_DVA_MODULES_ANNUAL}"
    return f"{STOCK_FINANCIALS_MODULES_QUARTERLY},{STOCK_DVA_MODULES_QUARTERLY}"


def benchmark_label(symbol: str) -> str:
    normalized = symbol.upper().strip()
    return BENCHMARK_LABELS.get(normalized, normalized)


def _normalize_recommendation(value: str | None) -> str | None:
    if not value:
        return None
    cleaned = value.strip().lower().replace("-", "_")
    return cleaned or None


def map_stock_fundamentals(item: dict) -> StockFundamentals:
    financial = item.get("financialData") or {}
    stats = item.get("defaultKeyStatistics") or {}
    analyst_count = financial.get("numberOfAnalystOpinions")

    return StockFundamentals(
        dividend_yield_12m=_as_pct(stats.get("dividendYield")),
        price_earnings=_pick_float(item.get("priceEarnings"), stats.get("trailingPE")),
        price_to_book=stats.get("priceToBook"),
        return_on_equity=_as_pct(financial.get("returnOnEquity")),
        return_on_assets=_as_pct(financial.get("returnOnAssets")),
        profit_margin=_as_pct(_pick_float(financial.get("profitMargins"), stats.get("profitMargins"))),
        debt_to_equity=financial.get("debtToEquity"),
        payout_ratio=_as_pct(stats.get("payoutRatio")),
        beta=stats.get("beta"),
        book_value_per_share=stats.get("bookValue"),
        earnings_per_share=item.get("earningsPerShare"),
        free_cashflow=financial.get("freeCashflow"),
        earnings_growth=_as_pct(financial.get("earningsGrowth")),
        total_revenue=financial.get("totalRevenue"),
        ebitda=financial.get("ebitda"),
        enterprise_value=stats.get("enterpriseValue"),
        enterprise_to_ebitda=stats.get("enterpriseToEbitda"),
        forward_pe=stats.get("forwardPE"),
        gross_margin=_as_pct(financial.get("grossMargins")),
        operating_margin=_as_pct(financial.get("operatingMargins")),
        revenue_growth=_as_pct(financial.get("revenueGrowth")),
        total_cash=financial.get("totalCash"),
        total_debt=financial.get("totalDebt"),
        current_ratio=financial.get("currentRatio"),
        target_mean_price=financial.get("targetMeanPrice"),
        recommendation_key=_normalize_recommendation(financial.get("recommendationKey")),
        number_of_analyst_opinions=int(analyst_count) if analyst_count is not None else None,
    )


def map_market_stats(item: dict) -> StockMarketStats:
    fundamentals = map_stock_fundamentals(item)
    return StockMarketStats(
        open=item.get("regularMarketOpen"),
        day_high=item.get("regularMarketDayHigh"),
        day_low=item.get("regularMarketDayLow"),
        previous_close=item.get("regularMarketPreviousClose"),
        volume=item.get("regularMarketVolume"),
        market_cap=item.get("marketCap"),
        price_earnings=fundamentals.price_earnings,
        earnings_per_share=fundamentals.earnings_per_share,
        fifty_two_week_low=item.get("fiftyTwoWeekLow"),
        fifty_two_week_high=item.get("fiftyTwoWeekHigh"),
        fifty_two_week_range=item.get("fiftyTwoWeekRange"),
    )


def map_stock_candles(
    *,
    ticker: str,
    price_points: list[dict],
    limit: int | None = None,
    interval: str = "1d",
    range_: str | None = None,
) -> FiiCandlesResponse:
    normalized_interval = normalize_candle_interval(interval)
    intraday = is_intraday_interval(normalized_interval)
    candles: list[FiiCandleBar] = []
    for point in price_points:
        ts = point.get("date")
        if ts is None:
            continue
        open_ = point.get("open")
        high = point.get("high")
        low = point.get("low")
        close = point.get("close")
        if None in (open_, high, low, close):
            continue
        dt = datetime.fromtimestamp(int(ts), tz=UTC)
        trade_date = dt.strftime("%Y-%m-%dT%H:%M:%S") if intraday else dt.strftime("%Y-%m-%d")
        candles.append(
            FiiCandleBar(
                trade_date=trade_date,
                open=float(open_),
                high=float(high),
                low=float(low),
                close=float(close),
                volume=float(point["volume"]) if point.get("volume") is not None else None,
            )
        )

    candles.sort(key=lambda bar: bar.trade_date)
    if limit and len(candles) > limit:
        candles = candles[-limit:]

    return FiiCandlesResponse(
        ticker=ticker.upper(),
        count=len(candles),
        candles=candles,
        provider="brapi",
        interval=normalized_interval,
        range=range_,
    )


def _normalize_label(value: str | None) -> str | None:
    if not value:
        return None
    cleaned = value.strip()
    if not cleaned:
        return None
    return cleaned.title()


def _payment_year(reference_date: str | None, payment_date: str | None) -> int | None:
    for raw in (payment_date, reference_date):
        if raw and len(raw) >= 4:
            try:
                return int(raw[:4])
            except ValueError:
                continue
    return None


def map_stock_dividends(*, ticker: str, dividends_data: dict | None, limit: int = 120) -> StockDividendsResponse:
    raw = (dividends_data or {}).get("cashDividends") or []
    stock_raw = (dividends_data or {}).get("stockDividends") or []
    payments: list[FiiDistributionPayment] = []
    by_year: dict[int, list[float]] = defaultdict(list)

    for item in raw:
        rate = item.get("rate")
        if rate is None:
            continue
        ref = _normalize_date(item.get("lastDatePrior"))
        paid = _normalize_date(item.get("paymentDate"))
        payments.append(
            FiiDistributionPayment(
                reference_date=ref,
                payment_date=paid,
                value_per_share=float(rate),
                label=_normalize_label(item.get("label")),
            )
        )
        year = _payment_year(ref, paid)
        if year is not None:
            by_year[year].append(float(rate))

    payments.sort(key=lambda payment: payment.payment_date or payment.reference_date or "", reverse=True)

    annual_summary = [
        FiiDistributionYearSummary(
            year=year,
            total_per_share=round(sum(values), 4),
            payments=len(values),
        )
        for year, values in sorted(by_year.items(), reverse=True)
    ]

    ttm_per_share = (
        round(sum(payment.value_per_share or 0 for payment in payments[:12]), 4) if payments else None
    )

    corporate_actions: list[StockCorporateAction] = []
    for item in stock_raw:
        corporate_actions.append(
            StockCorporateAction(
                label=_normalize_label(item.get("label")),
                factor=float(item["factor"]) if item.get("factor") is not None else None,
                complete_factor=item.get("completeFactor"),
                ex_date=_normalize_date(item.get("lastDatePrior")),
            )
        )

    limited = payments[:limit]

    return StockDividendsResponse(
        ticker=ticker.upper(),
        count=len(limited),
        total_payments=len(payments),
        ttm_per_share=ttm_per_share,
        annual_summary=annual_summary,
        payments=limited,
        corporate_actions=corporate_actions,
    )


LineSpec = tuple[str, str, str]

INCOME_STATEMENT_LINES: list[LineSpec] = [
    ("total_revenue", "Receita líquida", "totalRevenue"),
    ("cost_of_revenue", "CPV", "costOfRevenue"),
    ("gross_profit", "Lucro bruto", "grossProfit"),
    ("operating_income", "Lucro operacional", "operatingIncome"),
    ("ebit", "EBIT", "ebit"),
    ("ebitda", "EBITDA", "cleanEbitda"),
    ("income_before_tax", "LAIR", "incomeBeforeTax"),
    ("net_income", "Lucro líquido", "netIncome"),
]

BALANCE_SHEET_LINES: list[LineSpec] = [
    ("total_assets", "Ativo total", "totalAssets"),
    ("total_current_assets", "Ativo circulante", "totalCurrentAssets"),
    ("cash", "Caixa", "cash"),
    ("total_liab", "Passivo total", "totalLiab"),
    ("total_current_liabilities", "Passivo circulante", "totalCurrentLiabilities"),
    ("long_term_debt", "Dívida LP", "longTermDebt"),
    ("total_stockholder_equity", "Patrimônio líquido", "totalStockholderEquity"),
]

CASH_FLOW_LINES: list[LineSpec] = [
    ("operating_cash_flow", "Caixa operacional", "operatingCashFlow"),
    ("investment_cash_flow", "Caixa investimento", "investmentCashFlow"),
    ("financing_cash_flow", "Caixa financiamento", "financingCashFlow"),
    ("free_cash_flow", "Fluxo de caixa livre", "freeCashFlow"),
    ("increase_or_decrease_in_cash", "Variação de caixa", "increaseOrDecreaseInCash"),
    ("final_cash_balance", "Saldo final de caixa", "finalCashBalance"),
]

DVA_LINES: list[LineSpec] = [
    ("revenue", "Receita", "revenue"),
    ("supplies_purchased", "Insumos adquiridos", "suppliesPurchasedFromThirdParties"),
    ("gross_added_value", "Valor adicionado bruto", "grossAddedValue"),
    ("depreciation", "Depreciação e amortização", "depreciationAndAmortization"),
    ("net_added_value", "Valor adicionado líquido", "netAddedValue"),
    ("added_value_to_distribute", "VA total a distribuir", "addedValueToDistribute"),
    ("team_remuneration", "Pessoal", "teamRemuneration"),
    ("taxes", "Impostos", "taxes"),
    ("third_party_capital", "Remuneração cap. terceiros", "remunerationOfThirdPartyCapitals"),
    ("own_equity_remuneration", "Remuneração cap. próprio", "ownEquityRemuneration"),
]

DVA_ABS_KEYS = frozenset(
    {
        "supplies_purchased",
        "depreciation",
        "third_party_capital",
    }
)


def _normalize_financial_value(key: str, value: float | None) -> float | None:
    if value is None:
        return None
    if key in {"cost_of_revenue", "interest_expense", "income_tax_expense"}:
        return abs(float(value))
    return float(value)


def _map_financial_periods(
    raw_items: list[dict],
    specs: list[LineSpec],
    *,
    limit: int,
) -> list[FinancialPeriod]:
    sorted_items = sorted(
        raw_items,
        key=lambda item: item.get("endDate") or "",
        reverse=True,
    )[:limit]

    periods: list[FinancialPeriod] = []
    for item in sorted_items:
        end_date = _normalize_date(item.get("endDate"))
        if not end_date:
            continue
        lines = [
            FinancialLine(
                key=key,
                label=label,
                value=_normalize_financial_value(key, item.get(brapi_key)),
            )
            for key, label, brapi_key in specs
        ]
        periods.append(FinancialPeriod(end_date=end_date, lines=lines))
    return periods


def _normalize_dva_value(key: str, value: float | None) -> float | None:
    if value is None:
        return None
    if key in DVA_ABS_KEYS:
        return abs(float(value))
    return float(value)


def _map_dva_periods(raw_items: list[dict], *, limit: int) -> list[FinancialPeriod]:
    sorted_items = sorted(
        raw_items,
        key=lambda item: item.get("endDate") or "",
        reverse=True,
    )[:limit]

    periods: list[FinancialPeriod] = []
    for item in sorted_items:
        end_date = _normalize_date(item.get("endDate"))
        if not end_date:
            continue
        lines = [
            FinancialLine(
                key=key,
                label=label,
                value=_normalize_dva_value(key, item.get(brapi_key)),
            )
            for key, label, brapi_key in DVA_LINES
        ]
        periods.append(FinancialPeriod(end_date=end_date, lines=lines))
    return periods


def map_stock_financials(
    *,
    ticker: str,
    item: dict,
    limit: int = 8,
    period: str = "quarterly",
) -> StockFinancialsResponse:
    normalized = ticker.upper().strip()
    normalized_period = normalize_financial_period(period)
    if normalized_period == "annual":
        income_key = "incomeStatementHistory"
        balance_key = "balanceSheetHistory"
        cashflow_key = "cashflowHistory"
        dva_key = "valueAddedHistory"
    else:
        income_key = "incomeStatementHistoryQuarterly"
        balance_key = "balanceSheetHistoryQuarterly"
        cashflow_key = "cashflowHistoryQuarterly"
        dva_key = "valueAddedHistoryQuarterly"

    return StockFinancialsResponse(
        ticker=normalized,
        period=normalized_period,
        income_statement=_map_financial_periods(
            item.get(income_key) or [],
            INCOME_STATEMENT_LINES,
            limit=limit,
        ),
        balance_sheet=_map_financial_periods(
            item.get(balance_key) or [],
            BALANCE_SHEET_LINES,
            limit=limit,
        ),
        cash_flow=_map_financial_periods(
            item.get(cashflow_key) or [],
            CASH_FLOW_LINES,
            limit=limit,
        ),
        value_added=_map_dva_periods(item.get(dva_key) or [], limit=limit),
    )


def _return_pct_series(candles: list[FiiCandleBar]) -> dict[str, float]:
    if not candles:
        return {}
    sorted_candles = sorted(candles, key=lambda bar: bar.trade_date)
    base = sorted_candles[0].close
    if base == 0:
        return {}
    return {
        bar.trade_date: round(((bar.close / base) - 1) * 100, 4)
        for bar in sorted_candles
    }


def map_stock_performance(
    *,
    ticker: str,
    benchmark: str,
    range_: str,
    ticker_candles: list[FiiCandleBar],
    benchmark_candles: list[FiiCandleBar],
) -> StockPerformanceResponse:
    normalized = ticker.upper().strip()
    normalized_benchmark = benchmark.upper().strip()
    ticker_returns = _return_pct_series(ticker_candles)
    benchmark_returns = _return_pct_series(benchmark_candles)
    common_dates = sorted(set(ticker_returns) & set(benchmark_returns))

    points = [
        PerformancePoint(
            trade_date=trade_date,
            ticker_return_pct=ticker_returns[trade_date],
            benchmark_return_pct=benchmark_returns[trade_date],
        )
        for trade_date in common_dates
    ]

    ticker_total = points[-1].ticker_return_pct if points else None
    benchmark_total = points[-1].benchmark_return_pct if points else None

    return StockPerformanceResponse(
        ticker=normalized,
        benchmark=normalized_benchmark,
        benchmark_label=benchmark_label(normalized_benchmark),
        range=range_,
        count=len(points),
        ticker_return_pct=ticker_total,
        benchmark_return_pct=benchmark_total,
        points=points,
    )


def map_stock_compare_item(item: dict) -> StockCompareItem:
    return StockCompareItem(
        quote=map_market_quote(item),
        profile=map_stock_profile(item),
        fundamentals=map_stock_fundamentals(item),
        market_stats=map_market_stats(item),
    )


def enrich_screener_item(base: StockScreenerItem, item: dict) -> StockScreenerItem:
    fundamentals = map_stock_fundamentals(item)
    return base.model_copy(
        update={
            "dividend_yield_12m": fundamentals.dividend_yield_12m,
            "price_earnings": fundamentals.price_earnings,
            "return_on_equity": fundamentals.return_on_equity,
            "price_to_book": fundamentals.price_to_book,
        }
    )


def passes_fundamental_filters(
    item: StockScreenerItem,
    *,
    min_dividend_yield: float | None = None,
    max_dividend_yield: float | None = None,
    min_price_earnings: float | None = None,
    max_price_earnings: float | None = None,
    min_return_on_equity: float | None = None,
    max_return_on_equity: float | None = None,
    min_price_to_book: float | None = None,
    max_price_to_book: float | None = None,
) -> bool:
    checks = (
        (min_dividend_yield, item.dividend_yield_12m, lambda value, bound: value >= bound),
        (max_dividend_yield, item.dividend_yield_12m, lambda value, bound: value <= bound),
        (min_price_earnings, item.price_earnings, lambda value, bound: value >= bound),
        (max_price_earnings, item.price_earnings, lambda value, bound: value <= bound),
        (min_return_on_equity, item.return_on_equity, lambda value, bound: value >= bound),
        (max_return_on_equity, item.return_on_equity, lambda value, bound: value <= bound),
        (min_price_to_book, item.price_to_book, lambda value, bound: value >= bound),
        (max_price_to_book, item.price_to_book, lambda value, bound: value <= bound),
    )
    for bound, value, predicate in checks:
        if bound is None:
            continue
        if value is None:
            return False
        if not predicate(value, bound):
            return False
    return True


def _fundamental_sort_value(item: StockScreenerItem, sort_by: str) -> float:
    return {
        "dividend_yield": item.dividend_yield_12m,
        "price_earnings": item.price_earnings,
        "return_on_equity": item.return_on_equity,
        "price_to_book": item.price_to_book,
    }.get(sort_by, item.volume or 0.0) or 0.0


def sort_screener_items(
    items: list[StockScreenerItem],
    *,
    sort_by: str,
    sort_order: str,
) -> list[StockScreenerItem]:
    normalized = sort_by.strip().lower()
    if normalized not in SCREENER_FUNDAMENTAL_SORT:
        return items

    reverse = sort_order.lower() != "asc"
    return sorted(items, key=lambda item: _fundamental_sort_value(item, normalized), reverse=reverse)


def map_stock_fundamental_history(*, ticker: str, item: dict, limit: int = 12) -> StockFundamentalHistoryResponse:
    normalized = ticker.upper().strip()
    financial_rows = item.get("financialDataHistoryQuarterly") or []
    stats_rows = item.get("defaultKeyStatisticsHistoryQuarterly") or []

    stats_by_date: dict[str, dict] = {}
    for row in stats_rows:
        end_date = _normalize_date(row.get("endDate"))
        if end_date:
            stats_by_date[end_date] = row

    periods: list[FundamentalHistoryPeriod] = []
    for row in sorted(
        financial_rows,
        key=lambda entry: entry.get("endDate") or "",
        reverse=True,
    )[:limit]:
        end_date = _normalize_date(row.get("endDate"))
        if not end_date:
            continue
        stats = stats_by_date.get(end_date) or {}
        net_income = stats.get("netIncomeToCommon")
        periods.append(
            FundamentalHistoryPeriod(
                end_date=end_date,
                total_revenue=row.get("totalRevenue"),
                net_income=float(net_income) if net_income is not None else None,
                ebitda=row.get("ebitda"),
                free_cashflow=row.get("freeCashflow"),
                profit_margin=_as_pct(_pick_float(row.get("profitMargins"), stats.get("profitMargins"))),
                return_on_equity=_as_pct(row.get("returnOnEquity")),
                dividend_yield_12m=_as_pct(stats.get("dividendYield")),
                price_earnings=stats.get("trailingPE"),
                price_to_book=stats.get("priceToBook"),
            )
        )

    return StockFundamentalHistoryResponse(
        ticker=normalized,
        periods=periods,
        count=len(periods),
    )
