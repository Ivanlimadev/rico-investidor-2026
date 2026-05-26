from __future__ import annotations

from collections import defaultdict
from datetime import UTC, datetime

from app.clients.bolsai.models import (
    FiiCandleBar,
    FiiCandlesResponse,
    FiiDistributionPayment,
    FiiDistributionYearSummary,
)
from app.clients.brapi.models import (
    FinancialLine,
    FinancialPeriod,
    MarketQuote,
    StockCorporateAction,
    StockDividendsResponse,
    StockFinancialsResponse,
    StockFundamentals,
    StockMarketStats,
    StockProfile,
    StockCompareItem,
    StockScreenerItem,
    StockScreenerResponse,
)

STOCK_DETAIL_MODULES = "summaryProfile,financialData,defaultKeyStatistics"
STOCK_FINANCIALS_MODULES = (
    "incomeStatementHistoryQuarterly,balanceSheetHistoryQuarterly,cashflowHistoryQuarterly"
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
        logo_url=item.get("logo"),
    )


def _normalize_date(value: str | None) -> str | None:
    if not value:
        return None
    return value.split("T", 1)[0].split(" ", 1)[0]


VALID_CANDLE_RANGES = frozenset({"ytd", "1mo", "3mo", "6mo", "1y", "5y", "max"})


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


def map_stock_fundamentals(item: dict) -> StockFundamentals:
    financial = item.get("financialData") or {}
    stats = item.get("defaultKeyStatistics") or {}

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


def map_stock_candles(*, ticker: str, price_points: list[dict], limit: int | None = None) -> FiiCandlesResponse:
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
        trade_date = datetime.fromtimestamp(int(ts), tz=UTC).strftime("%Y-%m-%d")
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

    return FiiCandlesResponse(ticker=ticker.upper(), count=len(candles), candles=candles, provider="brapi")


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


def map_stock_financials(*, ticker: str, item: dict, limit: int = 8) -> StockFinancialsResponse:
    normalized = ticker.upper().strip()
    return StockFinancialsResponse(
        ticker=normalized,
        income_statement=_map_financial_periods(
            item.get("incomeStatementHistoryQuarterly") or [],
            INCOME_STATEMENT_LINES,
            limit=limit,
        ),
        balance_sheet=_map_financial_periods(
            item.get("balanceSheetHistoryQuarterly") or [],
            BALANCE_SHEET_LINES,
            limit=limit,
        ),
        cash_flow=_map_financial_periods(
            item.get("cashflowHistoryQuarterly") or [],
            CASH_FLOW_LINES,
            limit=limit,
        ),
    )


def map_stock_compare_item(item: dict) -> StockCompareItem:
    return StockCompareItem(
        quote=map_market_quote(item),
        profile=map_stock_profile(item),
        fundamentals=map_stock_fundamentals(item),
        market_stats=map_market_stats(item),
    )
