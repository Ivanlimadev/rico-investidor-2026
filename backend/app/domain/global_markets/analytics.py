from __future__ import annotations

from collections import defaultdict
from datetime import UTC, datetime, timedelta

from app.domain.global_markets.dividend_analytics import pick_next_dividend, resolve_frequency_label
from app.domain.global_markets.models import (
    GlobalStockCandle,
    GlobalStockCompanyProfile,
    GlobalStockDividend,
    GlobalStockDividendsSummary,
    GlobalStockReturnPeriod,
    GlobalStockTickerInfo,
)

# Aproximação em pregões (EUA ~252/ano) — mais fiel que meses × 30 dias.
RETURN_PERIODS: tuple[tuple[str, int], ...] = (
    ("1M", 21),
    ("3M", 63),
    ("1A", 252),
    ("2A", 504),
    ("3A", 756),
    ("5A", 1260),
)


def _dividend_bucket_year(item: GlobalStockDividend) -> int | None:
    """Ano do pagamento (preferido) ou data ex para totais anuais."""
    for raw in (item.payment_date, item.date, item.ex_date):
        day = _parse_day(raw) if raw else None
        if day is not None:
            return day.year
    return None


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

    recent_12m = [(day, item) for day, item in parsed if day >= cutoff_12m]
    ttm_total = sum(item.amount for _, item in recent_12m)
    payments_12m = len(recent_12m)
    avg_amount_12m = round(ttm_total / payments_12m, 4) if payments_12m > 0 else None

    annual: dict[int, float] = defaultdict(float)
    annual_payments: dict[int, int] = defaultdict(int)
    for _, item in parsed:
        bucket_year = _dividend_bucket_year(item)
        if bucket_year is None:
            continue
        annual[bucket_year] += item.amount
        annual_payments[bucket_year] += 1

    annual_rows = [
        {
            "year": year,
            "total": round(total, 4),
            "payments": annual_payments.get(year, 0),
        }
        for year, total in sorted(annual.items(), reverse=True)
    ]

    dividend_yield_ttm = round((ttm_total / price) * 100, 2) if price > 0 and ttm_total > 0 else None

    upcoming: list[GlobalStockDividend] = []
    for day, item in sorted(parsed, key=lambda row: row[0]):
        if day.date() >= now.date():
            upcoming.append(item)

    ordered = [item for _, item in sorted(parsed, key=lambda row: row[0], reverse=True)]
    next_dividend = pick_next_dividend(ordered, as_of=now)

    return GlobalStockDividendsSummary(
        ttm_per_share=round(ttm_total, 4) if ttm_total > 0 else None,
        dividend_yield_ttm=dividend_yield_ttm,
        payments_12m=payments_12m,
        annual_totals=annual_rows,
        upcoming=upcoming[:6],
        next_dividend=next_dividend,
        frequency_label=resolve_frequency_label(ordered[:12]),
        avg_amount_12m=avg_amount_12m,
        total_payments=len(parsed),
    )


def _price_sessions_back(candles: list[GlobalStockCandle], sessions_back: int) -> float | None:
    if not candles or sessions_back < 1:
        return None
    index = max(0, len(candles) - 1 - sessions_back)
    price = candles[index].close
    return price if price is not None and price > 0 else None


def compute_returns(
    candles: list[GlobalStockCandle],
    *,
    current_price: float | None = None,
    as_of: datetime | None = None,
) -> list[GlobalStockReturnPeriod]:
    if not candles:
        return []

    sorted_candles = sorted(candles, key=lambda candle: candle.date)
    latest_price = current_price
    if latest_price is None and sorted_candles:
        latest_price = sorted_candles[-1].close
    if latest_price is None or latest_price <= 0:
        return []

    rows: list[GlobalStockReturnPeriod] = []
    for label, sessions_back in RETURN_PERIODS:
        if len(sorted_candles) <= sessions_back:
            continue
        start_price = _price_sessions_back(sorted_candles, sessions_back)
        if start_price is None or start_price <= 0:
            continue
        return_pct = round(((latest_price - start_price) / start_price) * 100, 2)
        months_back = max(1, round(sessions_back / 21))
        rows.append(
            GlobalStockReturnPeriod(
                label=label,
                months_back=months_back,
                return_pct=return_pct,
            )
        )

    ytd_pct = _ytd_return_pct(sorted_candles, latest_price=latest_price, as_of=as_of)
    if ytd_pct is not None and not any(row.label == "YTD" for row in rows):
        rows.insert(
            min(2, len(rows)),
            GlobalStockReturnPeriod(label="YTD", months_back=1, return_pct=ytd_pct),
        )

    return rows


def _ytd_return_pct(
    sorted_candles: list[GlobalStockCandle],
    *,
    latest_price: float,
    as_of: datetime | None,
) -> float | None:
    """Rentabilidade no ano corrente (primeiro pregão do ano → última cotação)."""
    ref = as_of or datetime.now(UTC)
    year = ref.year
    start_price: float | None = None
    for candle in sorted_candles:
        day = _parse_day(candle.date)
        if day is None or day.year < year:
            continue
        close = candle.close
        if close is not None and close > 0:
            start_price = close
            break
    if start_price is None or start_price <= 0:
        return None
    return round(((latest_price - start_price) / start_price) * 100, 2)
