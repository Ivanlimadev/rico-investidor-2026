from __future__ import annotations

from app.clients.brapi.models import StockFundamentals, StockMarketStats, StockProfile
from app.domain.global_markets.models import (
    GlobalStockCompanyProfile,
    GlobalStockDividendsSummary,
    GlobalStockTickerInfo,
)


def _dig(raw: dict, *keys: str):
    current: object = raw
    for key in keys:
        if not isinstance(current, dict):
            return None
        current = current.get(key)
    return current


def _safe_float(value: object) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _safe_int(value: object) -> int | None:
    if value is None:
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _as_pct(value: object) -> float | None:
    parsed = _safe_float(value)
    if parsed is None:
        return None
    if abs(parsed) <= 1:
        return round(parsed * 100, 2)
    return round(parsed, 2)


def _valid_ratio(value: float | None, *, max_abs: float = 500.0) -> float | None:
    if value is None or value <= 0 or value > max_abs:
        return None
    return round(value, 4)


def unwrap_tickerinfo_payload(payload: dict | None) -> dict:
    if not payload:
        return {}
    data = payload.get("data")
    if isinstance(data, dict):
        return data
    return payload


def enrich_company_profile(
    profile: GlobalStockCompanyProfile,
    *,
    tickerinfo: dict | None,
) -> GlobalStockCompanyProfile:
    if not tickerinfo:
        return profile

    sector = _dig(tickerinfo, "sector") or _dig(tickerinfo, "profile", "sector")
    industry = _dig(tickerinfo, "industry") or _dig(tickerinfo, "profile", "industry")
    summary = (
        _dig(tickerinfo, "description")
        or _dig(tickerinfo, "long_description")
        or _dig(tickerinfo, "profile", "description")
        or _dig(tickerinfo, "profile", "longBusinessSummary")
    )
    website = _dig(tickerinfo, "website") or _dig(tickerinfo, "profile", "website")
    employees = _safe_int(
        _dig(tickerinfo, "employees")
        or _dig(tickerinfo, "profile", "fullTimeEmployees")
        or _dig(tickerinfo, "profile", "employees")
    )
    country = _dig(tickerinfo, "country") or _dig(tickerinfo, "profile", "country") or profile.country

    updates: dict = {}
    if isinstance(sector, str) and sector.strip():
        updates["sector"] = sector.strip()
    if isinstance(industry, str) and industry.strip():
        updates["industry"] = industry.strip()
    if isinstance(summary, str) and summary.strip():
        updates["summary"] = summary.strip()
    if isinstance(website, str) and website.strip():
        updates["website"] = website.strip()
    if employees is not None:
        updates["employees"] = employees
    if isinstance(country, str) and country.strip():
        updates["country"] = country.strip()

    return profile.model_copy(update=updates) if updates else profile


def map_fundamentals_from_tickerinfo(tickerinfo: dict | None) -> StockFundamentals:
    if not tickerinfo:
        return StockFundamentals(provider="marketstack")

    financial = _dig(tickerinfo, "financials") or _dig(tickerinfo, "financialData") or {}
    stats = _dig(tickerinfo, "statistics") or _dig(tickerinfo, "defaultKeyStatistics") or {}
    if not isinstance(financial, dict):
        financial = {}
    if not isinstance(stats, dict):
        stats = {}

    return StockFundamentals(
        dividend_yield_12m=_as_pct(
            _dig(tickerinfo, "dividend_yield")
            or stats.get("dividendYield")
            or financial.get("dividendYield")
        ),
        price_earnings=_valid_ratio(
            _safe_float(
                _dig(tickerinfo, "pe_ratio")
                or stats.get("trailingPE")
                or stats.get("pe_ratio")
                or tickerinfo.get("priceEarnings")
            )
        ),
        price_to_book=_valid_ratio(_safe_float(stats.get("priceToBook") or _dig(tickerinfo, "price_to_book"))),
        return_on_equity=_as_pct(financial.get("returnOnEquity") or _dig(tickerinfo, "return_on_equity")),
        return_on_assets=_as_pct(financial.get("returnOnAssets")),
        profit_margin=_as_pct(financial.get("profitMargins") or stats.get("profitMargins")),
        debt_to_equity=_safe_float(financial.get("debtToEquity")),
        payout_ratio=_as_pct(stats.get("payoutRatio")),
        beta=_safe_float(stats.get("beta") or _dig(tickerinfo, "beta")),
        book_value_per_share=_safe_float(stats.get("bookValue")),
        earnings_per_share=_safe_float(
            _dig(tickerinfo, "eps")
            or stats.get("trailingEps")
            or tickerinfo.get("earningsPerShare")
        ),
        free_cashflow=_safe_float(financial.get("freeCashflow")),
        earnings_growth=_as_pct(financial.get("earningsGrowth")),
        total_revenue=_safe_float(financial.get("totalRevenue") or _dig(tickerinfo, "revenue")),
        ebitda=_safe_float(financial.get("ebitda")),
        enterprise_value=_safe_float(stats.get("enterpriseValue")),
        enterprise_to_ebitda=_safe_float(stats.get("enterpriseToEbitda")),
        forward_pe=_safe_float(stats.get("forwardPE")),
        gross_margin=_as_pct(financial.get("grossMargins")),
        operating_margin=_as_pct(financial.get("operatingMargins")),
        revenue_growth=_as_pct(financial.get("revenueGrowth")),
        total_cash=_safe_float(financial.get("totalCash")),
        total_debt=_safe_float(financial.get("totalDebt")),
        current_ratio=_safe_float(financial.get("currentRatio")),
        target_mean_price=_safe_float(financial.get("targetMeanPrice")),
        recommendation_key=(
            str(financial.get("recommendationKey")).strip().lower().replace("-", "_")
            if financial.get("recommendationKey")
            else None
        ),
        number_of_analyst_opinions=_safe_int(financial.get("numberOfAnalystOpinions")),
        provider="marketstack",
    )


def merge_fundamentals(
    *,
    tickerinfo: dict | None,
    dividends_summary: GlobalStockDividendsSummary,
) -> StockFundamentals:
    fundamentals = map_fundamentals_from_tickerinfo(tickerinfo)
    if (
        fundamentals.dividend_yield_12m is None
        and dividends_summary.dividend_yield_ttm is not None
        and dividends_summary.payments_12m > 0
    ):
        fundamentals = fundamentals.model_copy(
            update={"dividend_yield_12m": dividends_summary.dividend_yield_ttm}
        )
    return fundamentals


def build_market_stats_from_quote(
    *,
    open: float | None,
    high: float | None,
    low: float | None,
    volume: float | None,
    previous_close: float | None,
    tickerinfo: dict | None,
    fundamentals: StockFundamentals,
) -> StockMarketStats:
    market_cap = _safe_float(
        _dig(tickerinfo or {}, "market_cap")
        or _dig(tickerinfo or {}, "marketCapitalization")
        or _dig(tickerinfo or {}, "statistics", "marketCap")
    )
    return StockMarketStats(
        open=open,
        day_high=high,
        day_low=low,
        previous_close=previous_close,
        volume=volume,
        market_cap=market_cap,
        price_earnings=fundamentals.price_earnings,
        earnings_per_share=fundamentals.earnings_per_share,
        provider="marketstack",
    )


def to_stock_profile(
    *,
    ticker: GlobalStockTickerInfo,
    company: GlobalStockCompanyProfile,
) -> StockProfile:
    return StockProfile(
        sector=company.sector,
        industry=company.industry,
        website=company.website or company.exchange_website,
        summary=company.summary,
        employees=company.employees,
        country=company.country,
        provider="marketstack",
    )
