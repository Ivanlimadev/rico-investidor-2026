from __future__ import annotations

from datetime import UTC, date, datetime, timedelta
from statistics import mean

from app.domain.fii.models import FiiDistributionPayment, FiiDistributionYearSummary
from app.domain.global_markets.dividend_analytics import (
    pick_next_dividend,
    project_next_dividend,
    resolve_frequency_label,
)
from app.domain.global_markets.models import GlobalStockDividend
from app.domain.dividends.br_com_date import investidor10_br_com_date

_BR_FREQUENCY_DAYS = (
    (45, "Mensal"),
    (120, "Trimestral"),
    (200, "Semestral"),
    (400, "Anual"),
)


def _parse_day(raw: str | None) -> date | None:
    text = str(raw or "").strip()
    if len(text) < 10:
        return None
    try:
        return date.fromisoformat(text[:10])
    except ValueError:
        return None


def br_ex_date_from_com(com_date: str | None) -> str | None:
    """Inverso aproximado de investidor10_br_com_date (ex = com + 1 dia útil)."""
    com = _parse_day(com_date)
    if com is None:
        return None
    candidate = com + timedelta(days=1)
    while candidate.weekday() >= 5:
        candidate += timedelta(days=1)
    return candidate.isoformat()


def payments_to_global_dividends(
    payments: list[FiiDistributionPayment],
) -> list[GlobalStockDividend]:
    rows: list[GlobalStockDividend] = []
    for item in payments:
        amount = item.value_per_share
        if amount is None or amount <= 0:
            continue
        com = item.reference_date
        ex = br_ex_date_from_com(com) or com
        pay = item.payment_date
        rows.append(
            GlobalStockDividend(
                date=ex or com or pay or "",
                amount=float(amount),
                ex_date=ex,
                com_date=com,
                record_date=ex,
                payment_date=pay,
                frequency=None,
                is_projected=False,
            )
        )
    return rows


def _infer_frequency_label(payments: list[FiiDistributionPayment]) -> str | None:
    com_dates: list[date] = []
    for item in payments:
        day = _parse_day(item.reference_date)
        if day is not None:
            com_dates.append(day)
    if len(com_dates) < 2:
        return None
    com_dates.sort(reverse=True)
    gaps = [(com_dates[i] - com_dates[i + 1]).days for i in range(min(5, len(com_dates) - 1))]
    gaps = [gap for gap in gaps if gap > 0]
    if not gaps:
        return None
    median_gap = int(round(mean(gaps)))
    for max_days, label in _BR_FREQUENCY_DAYS:
        if median_gap <= max_days:
            return label
    return "Anual"


def investidor10_dy_atual(
    payments: list[FiiDistributionPayment],
    *,
    price: float,
    as_of: datetime | None = None,
) -> tuple[float | None, float | None]:
    """DY estilo Investidor10: proventos dos últimos 12 meses por data de pagamento.

    Retorna (dy_percent, ttm_per_share). Inclui parcelas já pagas; se não houver
    pagamento no período, usa janela por data com (reference_date).
    """
    if price <= 0 or not payments:
        return None, None

    now = (as_of or datetime.now(UTC)).date()
    cutoff = now - timedelta(days=365)

    paid_total = 0.0
    paid_count = 0
    for item in payments:
        pay_day = _parse_day(item.payment_date)
        amount = item.value_per_share
        if amount is None or amount <= 0 or pay_day is None:
            continue
        if cutoff <= pay_day <= now:
            paid_total += float(amount)
            paid_count += 1

    if paid_total > 0:
        ttm = round(paid_total, 4)
        return round((paid_total / price) * 100, 2), ttm

    com_total = 0.0
    for item in payments:
        com_day = _parse_day(item.reference_date)
        amount = item.value_per_share
        if amount is None or amount <= 0 or com_day is None:
            continue
        if com_day >= cutoff:
            com_total += float(amount)

    if com_total > 0:
        ttm = round(com_total, 4)
        return round((com_total / price) * 100, 2), ttm

    # Histórico existe, mas nada nos últimos 12m — DY 0% (estilo Investidor10).
    return 0.0, 0.0


def average_dy_over_years(
    annual_summary: list[FiiDistributionYearSummary],
    *,
    price: float,
    years: int,
    as_of: datetime | None = None,
) -> float | None:
    if price <= 0 or not annual_summary:
        return None
    current_year = (as_of or datetime.now(UTC)).year
    eligible = [
        row
        for row in annual_summary
        if row.year < current_year and row.total_per_share is not None and row.total_per_share > 0
    ]
    if not eligible:
        eligible = [row for row in annual_summary if row.total_per_share and row.total_per_share > 0]
    eligible.sort(key=lambda row: row.year, reverse=True)
    slice_ = eligible[:years]
    if not slice_:
        return None
    yearly_dy = [(float(row.total_per_share) / price) * 100 for row in slice_]
    return round(mean(yearly_dy), 2)


def resolve_display_dividend_yield(
    *,
    dividend_yield_display: float | None,
    dividend_yield_ttm: float | None,
) -> float | None:
    """DY exibido — preserva 0% (evita fallback indevido com `or`)."""
    if dividend_yield_display is not None:
        return dividend_yield_display
    return dividend_yield_ttm


def resolve_display_ttm_per_share(
    *,
    ttm_per_share_display: float | None,
    ttm_per_share: float | None,
) -> float | None:
    if ttm_per_share_display is not None:
        return ttm_per_share_display
    return ttm_per_share


def build_br_dividends_summary(
    payments: list[FiiDistributionPayment],
    annual_summary: list[FiiDistributionYearSummary],
    *,
    price: float,
    as_of: datetime | None = None,
) -> dict[str, object]:
    now = as_of or datetime.now(UTC)
    global_rows = payments_to_global_dividends(payments)
    ordered = sorted(global_rows, key=lambda row: row.date or "", reverse=True)

    dy_display, ttm_display = investidor10_dy_atual(payments, price=price, as_of=now)
    avg_12m = None
    cutoff = now.date() - timedelta(days=365)
    recent_amounts: list[float] = []
    for item in payments:
        pay_day = _parse_day(item.payment_date)
        amount = item.value_per_share
        if amount and pay_day and cutoff <= pay_day <= now.date():
            recent_amounts.append(float(amount))
    payments_12m = len(recent_amounts)
    if recent_amounts:
        avg_12m = round(mean(recent_amounts), 4)

    upcoming: list[GlobalStockDividend] = []
    for row in sorted(global_rows, key=lambda item: item.payment_date or item.com_date or item.date):
        pay_day = _parse_day(row.payment_date)
        com_day = _parse_day(row.com_date)
        anchor = pay_day or com_day
        if anchor is not None and anchor >= now.date():
            upcoming.append(row)

    next_item = pick_next_dividend(ordered, as_of=now)
    if next_item is None and ordered:
        next_item = project_next_dividend(ordered, as_of=now)

    next_label = _label_for_global(next_item, payments) if next_item else None
    frequency = resolve_frequency_label(ordered[:12]) or _infer_frequency_label(payments)

    return {
        "dividend_yield_display": dy_display,
        "ttm_per_share_display": ttm_display,
        "dividend_yield_avg_5y": average_dy_over_years(annual_summary, price=price, years=5, as_of=now),
        "dividend_yield_avg_10y": average_dy_over_years(annual_summary, price=price, years=10, as_of=now),
        "frequency_label": frequency,
        "avg_amount_12m": avg_12m,
        "payments_12m": payments_12m,
        "next_dividend": _next_from_global(next_item, label=next_label),
        "upcoming": [
            _next_from_global(row, label=_label_for_global(row, payments)) for row in upcoming[:6]
        ],
    }


def _label_for_global(
    item: GlobalStockDividend | None,
    payments: list[FiiDistributionPayment],
) -> str | None:
    if item is None:
        return None
    for payment in payments:
        if payment.reference_date == item.com_date and payment.value_per_share == item.amount:
            return payment.label
        if payment.payment_date == item.payment_date and payment.value_per_share == item.amount:
            return payment.label
    return None


def _next_from_global(
    item: GlobalStockDividend | None,
    *,
    label: str | None = None,
) -> dict[str, object] | None:
    if item is None:
        return None
    return {
        "label": label or "Provento",
        "com_date": item.com_date,
        "ex_date": item.ex_date or item.date,
        "payment_date": item.payment_date,
        "value_per_share": round(float(item.amount), 6) if item.amount else None,
        "is_projected": bool(item.is_projected),
    }

