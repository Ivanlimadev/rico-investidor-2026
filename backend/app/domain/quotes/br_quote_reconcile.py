from __future__ import annotations

from app.clients.bolsai.fundamentals_mapper import (
    bolsai_quote_updates,
    fundamentals_updates_from_bolsai,
)
from app.clients.brapi.models import MarketQuote
from app.domain.dividends.br_dividend_analytics import resolve_display_dividend_yield

_FUNDAMENTAL_LIST_KEYS = (
    "dividend_yield_12m",
    "price_to_book",
    "price_earnings",
    "return_on_equity",
)


def merge_bolsai_fundamentals_into_quote(
    quote: MarketQuote,
    *,
    fundamentals: dict | None,
    bolsai_quote: dict | None,
    display_dividend_yield: float | None,
) -> MarketQuote:
    """Alinha cotação e indicadores com Bolsai + DY estilo Investidor10."""
    updates: dict[str, object] = dict(
        bolsai_quote_updates(bolsai_quote, fundamentals=fundamentals),
    )

    if fundamentals:
        mapped = fundamentals_updates_from_bolsai(fundamentals)
        for key in _FUNDAMENTAL_LIST_KEYS:
            if key in mapped:
                updates[key] = mapped[key]

    if display_dividend_yield is not None:
        updates["dividend_yield_12m"] = display_dividend_yield

    if not updates:
        return quote
    return quote.model_copy(update=updates)


def resolved_list_dividend_yield(
    *,
    display_dividend_yield: float | None,
    fundamentals_dy: float | None,
    fallback_dy: float | None,
) -> float | None:
    """DY para listas — prioriza cálculo I10, depois fundamentos Bolsai."""
    if display_dividend_yield is not None:
        return display_dividend_yield
    if fundamentals_dy is not None:
        return fundamentals_dy
    return fallback_dy
