from __future__ import annotations

from datetime import UTC, date, datetime

from app.clients.brapi.models import StockCompareReturnPeriod
from app.clients.brapi.models import FiiCandleBar, FiiDistributionPayment

RETURN_PERIODS: tuple[tuple[str, int], ...] = (
    ("1M", 21),
    ("3M", 63),
    ("1A", 252),
    ("2A", 504),
    ("3A", 756),
    ("5A", 1260),
)


def _parse_day(raw: str | None) -> datetime | None:
    if not raw or len(raw) < 10:
        return None
    try:
        return datetime.strptime(raw[:10], "%Y-%m-%d").replace(tzinfo=UTC)
    except ValueError:
        return None


def _dividends_per_share_since(
    payments: list[FiiDistributionPayment],
    since: datetime,
    *,
    as_of: datetime,
) -> float:
    total = 0.0
    for item in payments:
        amount = item.value_per_share
        if amount is None or amount <= 0:
            continue
        event_day = _parse_day(item.payment_date) or _parse_day(item.reference_date)
        if event_day is None:
            continue
        if since <= event_day <= as_of:
            total += float(amount)
    return total


def _total_return_pct(
    *,
    latest_price: float,
    start_price: float,
    payments: list[FiiDistributionPayment],
    since: datetime,
    as_of: datetime,
) -> float:
    price_pct = ((latest_price - start_price) / start_price) * 100
    div_pct = (_dividends_per_share_since(payments, since, as_of=as_of) / start_price) * 100
    return round(price_pct + div_pct, 2)


def compute_stock_returns(
    candles: list[FiiCandleBar],
    *,
    current_price: float | None = None,
    payments: list[FiiDistributionPayment] | None = None,
    as_of: datetime | None = None,
) -> list[StockCompareReturnPeriod]:
    if not candles:
        return []

    sorted_candles = sorted(candles, key=lambda bar: bar.trade_date)
    latest_price = current_price if current_price and current_price > 0 else sorted_candles[-1].close
    if latest_price <= 0:
        return []

    ref = as_of or datetime.now(UTC)
    div_rows = payments or []
    rows: list[StockCompareReturnPeriod] = []

    for label, sessions_back in RETURN_PERIODS:
        if len(sorted_candles) <= sessions_back:
            continue
        start_index = max(0, len(sorted_candles) - 1 - sessions_back)
        start_bar = sorted_candles[start_index]
        start_price = start_bar.close
        if start_price <= 0:
            continue
        since = _parse_day(start_bar.trade_date) or ref
        return_pct = (
            _total_return_pct(
                latest_price=latest_price,
                start_price=start_price,
                payments=div_rows,
                since=since,
                as_of=ref,
            )
            if div_rows
            else round(((latest_price - start_price) / start_price) * 100, 2)
        )
        rows.append(
            StockCompareReturnPeriod(
                label=label,
                months_back=max(1, round(sessions_back / 21)),
                return_pct=return_pct,
            )
        )

    ytd_pct = _ytd_return_pct(
        sorted_candles,
        latest_price=latest_price,
        payments=div_rows,
        as_of=ref.date(),
    )
    if ytd_pct is not None and not any(row.label == "YTD" for row in rows):
        rows.insert(
            min(2, len(rows)),
            StockCompareReturnPeriod(label="YTD", months_back=1, return_pct=ytd_pct),
        )

    return rows


def _ytd_return_pct(
    sorted_candles: list[FiiCandleBar],
    *,
    latest_price: float,
    payments: list[FiiDistributionPayment],
    as_of: date,
) -> float | None:
    year_prefix = f"{as_of.year}-"
    start_price: float | None = None
    start_day: datetime | None = None
    for bar in sorted_candles:
        if not bar.trade_date.startswith(year_prefix):
            continue
        if bar.close <= 0:
            continue
        start_price = bar.close
        start_day = _parse_day(bar.trade_date)
        break
    if start_price is None or start_day is None:
        return None
    ref = datetime(as_of.year, as_of.month, as_of.day, tzinfo=UTC)
    if payments:
        return _total_return_pct(
            latest_price=latest_price,
            start_price=start_price,
            payments=payments,
            since=start_day,
            as_of=ref,
        )
    return round(((latest_price - start_price) / start_price) * 100, 2)
