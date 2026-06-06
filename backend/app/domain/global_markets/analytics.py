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


def _dividend_event_day(item: GlobalStockDividend, *, prefer_payment: bool) -> datetime | None:
    if prefer_payment:
        return _parse_day(item.payment_date)
    return _parse_day(item.date) or _parse_day(item.ex_date)


def _investidor10_ttm_totals(
    dividends: list[GlobalStockDividend],
    *,
    cutoff: datetime,
    now: datetime,
) -> tuple[float, int]:
    """TTM estilo Investidor10: janela de 12 meses por data de pagamento."""
    paid_total = 0.0
    paid_count = 0
    for item in dividends:
        pay_day = _dividend_event_day(item, prefer_payment=True)
        amount = item.amount
        if amount is None or amount <= 0 or pay_day is None:
            continue
        if cutoff <= pay_day <= now:
            paid_total += float(amount)
            paid_count += 1

    if paid_total > 0:
        return paid_total, paid_count

    com_total = 0.0
    com_count = 0
    for item in dividends:
        com_day = _parse_day(item.com_date) or _parse_day(item.date)
        amount = item.amount
        if amount is None or amount <= 0 or com_day is None:
            continue
        if cutoff <= com_day <= now:
            com_total += float(amount)
            com_count += 1

    if com_total > 0:
        return com_total, com_count

    ex_total = 0.0
    ex_count = 0
    for item in dividends:
        ex_day = _parse_day(item.date) or _parse_day(item.ex_date)
        amount = item.amount
        if amount is None or amount <= 0 or ex_day is None:
            continue
        if cutoff <= ex_day <= now:
            ex_total += float(amount)
            ex_count += 1

    return ex_total, ex_count


def _dividends_per_share_since(
    dividends: list[GlobalStockDividend],
    since: datetime,
    *,
    as_of: datetime,
) -> float:
    total = 0.0
    for item in dividends:
        event_day = _dividend_event_day(item, prefer_payment=True)
        if event_day is None:
            event_day = _parse_day(item.com_date) or _parse_day(item.date)
        amount = item.amount
        if amount is None or amount <= 0 or event_day is None:
            continue
        if since <= event_day <= as_of:
            total += float(amount)
    return total


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
        day = _parse_day(item.date) or _parse_day(item.ex_date)
        if day is not None:
            parsed.append((day, item))

    ttm_total, payments_12m = _investidor10_ttm_totals(dividends, cutoff=cutoff_12m, now=now)
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


def _series_has_split_adjustment(candles: list[GlobalStockCandle]) -> bool:
    for candle in candles:
        adj = candle.adj_close
        close = candle.close
        if adj is None or adj <= 0 or close is None or close <= 0:
            continue
        if abs(adj - close) > 0.001:
            return True
    return False


def _return_close(candle: GlobalStockCandle, *, use_adjusted: bool) -> float | None:
    if use_adjusted and candle.adj_close is not None and candle.adj_close > 0:
        return candle.adj_close
    if candle.close is not None and candle.close > 0:
        return candle.close
    if candle.adj_close is not None and candle.adj_close > 0:
        return candle.adj_close
    return None


def _price_sessions_back(
    candles: list[GlobalStockCandle],
    sessions_back: int,
    *,
    use_adjusted: bool,
) -> float | None:
    if not candles or sessions_back < 1:
        return None
    index = max(0, len(candles) - 1 - sessions_back)
    return _return_close(candles[index], use_adjusted=use_adjusted)


def _total_return_pct(
    *,
    latest_price: float,
    start_price: float,
    dividends: list[GlobalStockDividend],
    since: datetime,
    as_of: datetime,
) -> float:
    price_pct = ((latest_price - start_price) / start_price) * 100
    div_per_share = _dividends_per_share_since(dividends, since, as_of=as_of)
    div_pct = (div_per_share / start_price) * 100 if start_price > 0 else 0.0
    return round(price_pct + div_pct, 2)


def compute_returns(
    candles: list[GlobalStockCandle],
    *,
    current_price: float | None = None,
    dividends: list[GlobalStockDividend] | None = None,
    as_of: datetime | None = None,
) -> list[GlobalStockReturnPeriod]:
    if not candles:
        return []

    sorted_candles = sorted(candles, key=lambda candle: candle.date)
    use_adjusted = _series_has_split_adjustment(sorted_candles)
    latest_price = current_price
    if sorted_candles:
        adjusted_latest = _return_close(sorted_candles[-1], use_adjusted=use_adjusted)
        if use_adjusted and adjusted_latest is not None:
            latest_price = adjusted_latest
        elif latest_price is None:
            latest_price = adjusted_latest
    if latest_price is None or latest_price <= 0:
        return []

    ref = as_of or datetime.now(UTC)
    div_rows = dividends or []

    rows: list[GlobalStockReturnPeriod] = []
    for label, sessions_back in RETURN_PERIODS:
        if len(sorted_candles) <= sessions_back:
            continue
        start_index = max(0, len(sorted_candles) - 1 - sessions_back)
        start_candle = sorted_candles[start_index]
        start_price = _return_close(start_candle, use_adjusted=use_adjusted)
        if start_price is None or start_price <= 0:
            continue
        since = _parse_day(start_candle.date) or ref
        return_pct = (
            _total_return_pct(
                latest_price=latest_price,
                start_price=start_price,
                dividends=div_rows,
                since=since,
                as_of=ref,
            )
            if div_rows
            else round(((latest_price - start_price) / start_price) * 100, 2)
        )
        months_back = max(1, round(sessions_back / 21))
        rows.append(
            GlobalStockReturnPeriod(
                label=label,
                months_back=months_back,
                return_pct=return_pct,
            )
        )

    ytd_pct = _ytd_return_pct(
        sorted_candles,
        latest_price=latest_price,
        as_of=as_of,
        use_adjusted=use_adjusted,
        dividends=div_rows,
    )
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
    use_adjusted: bool = False,
    dividends: list[GlobalStockDividend] | None = None,
) -> float | None:
    """Rentabilidade no ano corrente (primeiro pregão do ano → última cotação)."""
    ref = as_of or datetime.now(UTC)
    year = ref.year
    start_price: float | None = None
    start_day: datetime | None = None
    for candle in sorted_candles:
        day = _parse_day(candle.date)
        if day is None or day.year < year:
            continue
        start_price = _return_close(candle, use_adjusted=use_adjusted)
        if start_price is not None and start_price > 0:
            start_day = day
            break
    if start_price is None or start_price <= 0 or start_day is None:
        return None
    if dividends:
        return _total_return_pct(
            latest_price=latest_price,
            start_price=start_price,
            dividends=dividends,
            since=start_day,
            as_of=ref,
        )
    return round(((latest_price - start_price) / start_price) * 100, 2)
