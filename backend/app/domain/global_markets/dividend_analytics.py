from __future__ import annotations

from datetime import UTC, datetime, timedelta
from statistics import mean, median, mode
from statistics import StatisticsError

from app.domain.global_markets.models import GlobalStockDividend
from app.domain.global_markets.us_dividend_dates import investidor10_com_date

FREQUENCY_LABELS: dict[str, str] = {
    "m": "Mensal",
    "q": "Trimestral",
    "s": "Semestral",
    "sa": "Semestral",
    "a": "Anual",
    "y": "Anual",
}

FREQUENCY_DAYS: dict[str, int] = {
    "m": 30,
    "q": 91,
    "s": 182,
    "sa": 182,
    "a": 365,
    "y": 365,
}


def _parse_day(raw: str | None) -> datetime | None:
    text = str(raw or "").strip()
    if len(text) < 10:
        return None
    try:
        return datetime.strptime(text[:10], "%Y-%m-%d").replace(tzinfo=UTC)
    except ValueError:
        return None


def frequency_label(raw: str | None) -> str | None:
    if not raw:
        return None
    return FREQUENCY_LABELS.get(raw.strip().lower())


def _mode_frequency(dividends: list[GlobalStockDividend]) -> str | None:
    counts: dict[str, int] = {}
    for item in dividends:
        key = (item.frequency or "").strip().lower()
        if not key:
            continue
        counts[key] = counts.get(key, 0) + 1
    if not counts:
        return None
    return max(counts, key=counts.get)


def resolve_frequency_label(dividends: list[GlobalStockDividend]) -> str | None:
    return frequency_label(_mode_frequency(dividends))


def _payment_lag_days(dividends: list[GlobalStockDividend]) -> int | None:
    gaps: list[int] = []
    for item in dividends:
        ex_day = _parse_day(item.ex_date or item.date)
        pay_day = _parse_day(item.payment_date)
        if ex_day is None or pay_day is None:
            continue
        gap = (pay_day.date() - ex_day.date()).days
        if gap >= 0:
            gaps.append(gap)
    if not gaps:
        return None
    try:
        return int(mode(gaps))
    except StatisticsError:
        return int(round(median(gaps)))


def project_next_dividend(
    dividends: list[GlobalStockDividend],
    *,
    as_of: datetime,
) -> GlobalStockDividend | None:
    if not dividends:
        return None

    parsed: list[tuple[datetime, GlobalStockDividend]] = []
    for item in dividends:
        day = _parse_day(item.ex_date or item.date)
        if day is not None:
            parsed.append((day, item))

    if not parsed:
        return None

    parsed.sort(key=lambda row: row[0], reverse=True)
    last_day, last_item = parsed[0]
    frequency_key = (last_item.frequency or _mode_frequency([row[1] for row in parsed[:8]] or []))
    frequency_key = (frequency_key or "").strip().lower() or None
    interval_days = FREQUENCY_DAYS.get(frequency_key or "", 91)

    recent_amounts = [row[1].amount for row in parsed[:4] if row[1].amount > 0]
    projected_amount = round(mean(recent_amounts), 4) if recent_amounts else last_item.amount

    next_ex = last_day + timedelta(days=interval_days)
    while next_ex.date() <= as_of.date():
        next_ex += timedelta(days=interval_days)

    payment_lag = _payment_lag_days([row[1] for row in parsed[:12]])
    payment_date = None
    if payment_lag is not None:
        payment_date = (next_ex + timedelta(days=payment_lag)).date().isoformat()

    return GlobalStockDividend(
        date=next_ex.date().isoformat(),
        amount=projected_amount,
        ex_date=next_ex.date().isoformat(),
        com_date=investidor10_com_date(next_ex.date().isoformat()),
        record_date=next_ex.date().isoformat(),
        payment_date=payment_date,
        frequency=frequency_key,
        is_projected=True,
    )


def enrich_dividend_dates(dividends: list[GlobalStockDividend]) -> list[GlobalStockDividend]:
    if not dividends:
        return dividends

    # Só estima pagamento quando há histórico real ex→pagamento (evita +3 dias errado em KO etc.)
    lag = _payment_lag_days(dividends)
    enriched: list[GlobalStockDividend] = []

    for item in dividends:
        ex = item.ex_date or item.date
        com = item.com_date or investidor10_com_date(ex)
        record = item.record_date or ex
        payment = item.payment_date
        if not payment and ex and lag is not None:
            ex_day = _parse_day(ex)
            if ex_day is not None:
                payment = (ex_day + timedelta(days=lag)).date().isoformat()

        enriched.append(
            item.model_copy(
                update={
                    "ex_date": ex,
                    "com_date": com,
                    "record_date": record,
                    "payment_date": payment,
                }
            )
        )

    return enriched


def pick_next_dividend(
    dividends: list[GlobalStockDividend],
    *,
    as_of: datetime,
) -> GlobalStockDividend | None:
    upcoming: list[tuple[datetime, GlobalStockDividend]] = []
    for item in dividends:
        if item.is_projected:
            continue
        for candidate in (item.payment_date, item.ex_date or item.date):
            day = _parse_day(candidate)
            if day is not None and day.date() >= as_of.date():
                upcoming.append((day, item))
                break

    if upcoming:
        upcoming.sort(key=lambda row: row[0])
        return upcoming[0][1]

    return project_next_dividend(dividends, as_of=as_of)
