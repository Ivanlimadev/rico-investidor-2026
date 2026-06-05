from __future__ import annotations

from collections import defaultdict
from datetime import date

from app.clients.bolsai.models import BolsaiDividendsResponse
from app.clients.brapi.models import StockDividendsResponse
from app.domain.dividends.br_com_date import investidor10_br_com_date
from app.domain.fii.models import (
    FiiDistributionPayment,
    FiiDistributions,
    FiiDistributionYearSummary,
)


def _normalize_label(value: str | None) -> str:
    if not value or not value.strip():
        return "Dividendo"
    return value.strip().title()


def _day_only(value: str | None) -> str | None:
    if not value:
        return None
    return str(value).strip()[:10]


def _payment_year(reference: str | None, payment: str | None) -> int | None:
    for raw in (payment, reference):
        if raw and len(raw) >= 4:
            try:
                return int(raw[:4])
            except ValueError:
                continue
    return None


def map_bolsai_stock_dividends(
    payload: BolsaiDividendsResponse,
    *,
    limit: int = 120,
) -> StockDividendsResponse:
    symbol = payload.ticker.upper().strip()
    payments: list[FiiDistributionPayment] = []
    by_year: dict[int, list[float]] = defaultdict(list)

    for item in payload.payments:
        ex_raw = _day_only(item.ex_date)
        com_date = investidor10_br_com_date(ex_raw) or ex_raw
        if not com_date:
            continue
        amount = item.value_per_share
        if amount is None:
            continue
        paid = _day_only(item.payment_date)
        payments.append(
            FiiDistributionPayment(
                reference_date=com_date,
                payment_date=paid,
                value_per_share=float(amount),
                label=_normalize_label(item.type),
            )
        )
        year = _payment_year(com_date, paid)
        if year is not None:
            by_year[year].append(float(amount))

    payments.sort(
        key=lambda row: row.payment_date or row.reference_date or "",
        reverse=True,
    )
    limited = payments[: max(1, limit)]

    annual_summary = [
        FiiDistributionYearSummary(
            year=year,
            total_per_share=round(sum(values), 4),
            payments=len(values),
        )
        for year, values in sorted(by_year.items(), reverse=True)
    ]

    ttm = payload.ttm_per_share
    if ttm is None and limited:
        ttm = round(sum(p.value_per_share or 0 for p in limited[:12]), 4)

    return StockDividendsResponse(
        ticker=symbol,
        count=len(limited),
        total_payments=payload.total_payments or len(payments),
        ttm_per_share=ttm,
        dividend_yield_ttm=payload.dividend_yield_ttm,
        annual_summary=annual_summary,
        payments=limited,
        corporate_actions=[],
        provider="bolsai",
    )


def map_bolsai_fii_distributions(
    payload: BolsaiDividendsResponse,
    *,
    years: int = 5,
    name: str | None = None,
    close_price: float | None = None,
    dividend_yield_ttm: float | None = None,
) -> FiiDistributions:
    symbol = payload.ticker.upper().strip()
    display_name = (name or payload.name or symbol).strip()
    cutoff_year = date.today().year - max(1, years) + 1

    payments: list[FiiDistributionPayment] = []
    by_year: dict[int, list[float]] = defaultdict(list)

    for item in payload.payments:
        ref = _day_only(item.reference_date or item.ex_date)
        if not ref:
            continue
        year = _payment_year(ref, _day_only(item.payment_date))
        if year is not None and year < cutoff_year:
            continue
        amount = item.value_per_share
        if amount is None:
            continue
        paid = _day_only(item.payment_date)
        payments.append(
            FiiDistributionPayment(
                reference_date=ref,
                payment_date=paid,
                value_per_share=float(amount),
                dy_month_pct=item.dy_month_pct,
                book_value_per_share=item.book_value_per_share,
                label=_normalize_label(item.type) if item.type else "Rendimento",
            )
        )
        if year is not None:
            by_year[year].append(float(amount))

    payments.sort(
        key=lambda row: row.reference_date or row.payment_date or "",
        reverse=True,
    )

    annual_summary = [
        FiiDistributionYearSummary(
            year=year,
            total_per_share=round(sum(values), 4),
            payments=len(values),
        )
        for year, values in sorted(by_year.items(), reverse=True)
    ]

    ttm = payload.ttm_per_share
    if ttm is None and payments:
        ttm = round(sum(p.value_per_share or 0 for p in payments[:12]), 4)

    return FiiDistributions(
        ticker=symbol,
        name=display_name,
        dividend_yield_ttm=dividend_yield_ttm if dividend_yield_ttm is not None else payload.dividend_yield_ttm,
        ttm_per_share=ttm,
        close_price=close_price if close_price is not None else payload.close_price,
        total_payments=len(payments),
        annual_summary=annual_summary,
        payments=payments,
        provider="bolsai",
    )
