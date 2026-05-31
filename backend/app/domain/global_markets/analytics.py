from __future__ import annotations

from collections import defaultdict
from datetime import UTC, datetime, timedelta

from app.domain.global_markets.models import (
    GlobalStockCandle,
    GlobalStockCompanyProfile,
    GlobalStockDividend,
    GlobalStockDividendsSummary,
    GlobalStockReturnPeriod,
    GlobalStockTickerInfo,
)

RETURN_PERIODS: tuple[tuple[str, int], ...] = (
    ("1M", 1),
    ("3M", 3),
    ("1A", 12),
    ("2A", 24),
    ("3A", 36),
    ("5A", 60),
)


def _parse_day(raw: str) -> datetime | None:
    text = str(raw or "").strip()
    if len(text) < 10:
        return None
    try:
        return datetime.strptime(text[:10], "%Y-%m-%d").replace(tzinfo=UTC)
    except ValueError:
        return None


def build_company_profile(ticker: GlobalStockTickerInfo) -> GlobalStockCompanyProfile:
    return GlobalStockCompanyProfile(
        symbol=ticker.symbol,
        name=ticker.name,
        country=ticker.country,
        exchange_mic=ticker.exchange_mic,
        exchange_name=ticker.exchange_name,
        exchange_acronym=ticker.exchange_acronym,
        exchange_city=ticker.exchange_city,
        exchange_country_code=ticker.exchange_country_code,
        exchange_website=ticker.exchange_website,
        has_eod=ticker.has_eod,
        has_intraday=ticker.has_intraday,
        isin=ticker.isin,
        cusip=ticker.cusip,
    )


def summarize_dividends(
    dividends: list[GlobalStockDividend],
    *,
    price: float,
    as_of: datetime | None = None,
) -> GlobalStockDividendsSummary:
    now = as_of or datetime.now(UTC)
    cutoff_12m = now - timedelta(days=365)

    parsed: list[tuple[datetime, GlobalStockDividend]] = []
    for item in dividends:
        day = _parse_day(item.date)
        if day is not None:
            parsed.append((day, item))

    ttm_total = sum(item.amount for day, item in parsed if day >= cutoff_12m)
    payments_12m = sum(1 for day, _ in parsed if day >= cutoff_12m)

    annual: dict[int, float] = defaultdict(float)
    for day, item in parsed:
        annual[day.year] += item.amount

    annual_rows = [
        {"year": year, "total": round(total, 4)}
        for year, total in sorted(annual.items(), reverse=True)
    ]

    dividend_yield_ttm = round((ttm_total / price) * 100, 2) if price > 0 and ttm_total > 0 else None

    upcoming: list[GlobalStockDividend] = []
    for day, item in sorted(parsed, key=lambda row: row[0]):
        if day.date() >= now.date():
            upcoming.append(item)

    return GlobalStockDividendsSummary(
        ttm_per_share=round(ttm_total, 4) if ttm_total > 0 else None,
        dividend_yield_ttm=dividend_yield_ttm,
        payments_12m=payments_12m,
        annual_totals=annual_rows,
        upcoming=upcoming[:6],
        total_payments=len(parsed),
    )


def _price_at_or_before(candles: list[GlobalStockCandle], target: datetime) -> float | None:
    best_date: datetime | None = None
    best_price: float | None = None
    for candle in candles:
        day = _parse_day(candle.date)
        if day is None or day > target:
            continue
        if best_date is None or day >= best_date:
            best_date = day
            best_price = candle.close
    return best_price


def compute_returns(
    candles: list[GlobalStockCandle],
    *,
    current_price: float | None = None,
    as_of: datetime | None = None,
) -> list[GlobalStockReturnPeriod]:
    if not candles:
        return []

    now = as_of or datetime.now(UTC)
    sorted_candles = sorted(candles, key=lambda candle: candle.date)
    latest_price = current_price
    if latest_price is None and sorted_candles:
        latest_price = sorted_candles[-1].close
    if latest_price is None or latest_price <= 0:
        return []

    rows: list[GlobalStockReturnPeriod] = []
    for label, months in RETURN_PERIODS:
        target = now - timedelta(days=months * 30)
        start_price = _price_at_or_before(sorted_candles, target)
        if start_price is None or start_price <= 0:
            rows.append(GlobalStockReturnPeriod(label=label, months_back=months))
            continue
        return_pct = round(((latest_price - start_price) / start_price) * 100, 2)
        rows.append(
            GlobalStockReturnPeriod(
                label=label,
                months_back=months,
                return_pct=return_pct,
            )
        )
    return rows
