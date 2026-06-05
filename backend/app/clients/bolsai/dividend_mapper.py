from __future__ import annotations

from app.clients.brapi.models import StockDividendsResponse
from app.domain.dividends.calendar_models import DividendCalendarEntry
from app.domain.fii.models import FiiDistributions


def calendar_entries_from_stock_dividends(
    dividends: StockDividendsResponse,
    *,
    company_name: str | None = None,
) -> list[DividendCalendarEntry]:
    symbol = dividends.ticker.upper().strip()
    name = (company_name or symbol).strip()
    rows: list[DividendCalendarEntry] = []

    for payment in dividends.payments:
        com_date = payment.reference_date
        if not com_date:
            continue
        amount = payment.value_per_share
        if amount is None:
            continue
        rows.append(
            DividendCalendarEntry(
                market="br",
                symbol=symbol,
                company_name=name,
                exchange="B3",
                dividend_type=(payment.label or "Dividendo").strip().title(),
                com_date=com_date,
                payment_date=payment.payment_date,
                amount=round(float(amount), 4),
                currency="BRL",
            )
        )
    return rows


def calendar_entries_from_fii_distributions(
    distributions: FiiDistributions,
) -> list[DividendCalendarEntry]:
    return calendar_entries_from_stock_dividends(
        StockDividendsResponse(
            ticker=distributions.ticker,
            count=len(distributions.payments),
            total_payments=distributions.total_payments,
            ttm_per_share=distributions.ttm_per_share,
            annual_summary=distributions.annual_summary,
            payments=distributions.payments,
            provider=distributions.provider,
        ),
        company_name=distributions.name,
    )
