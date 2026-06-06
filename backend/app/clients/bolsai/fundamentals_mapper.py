from __future__ import annotations

from app.clients.brapi.models import StockFundamentals, StockMarketStats


def _float(payload: dict, *keys: str) -> float | None:
    for key in keys:
        raw = payload.get(key)
        if raw is None:
            continue
        try:
            return round(float(raw), 4)
        except (TypeError, ValueError):
            continue
    return None


# Campos reais da Bolsai (/fundamentals/{ticker}) → StockFundamentals.
_FUNDAMENTALS_MAP: tuple[tuple[str, tuple[str, ...]], ...] = (
    ("dividend_yield_12m", ("dividend_yield", "dividend_yield_ttm", "dy")),
    ("price_earnings", ("price_earnings", "pe", "p_l", "pl")),
    ("price_to_book", ("price_to_book", "pvp", "p_vp")),
    ("return_on_equity", ("return_on_equity", "roe")),
    ("return_on_assets", ("return_on_assets", "roa")),
    ("profit_margin", ("profit_margin", "net_margin", "margem_liquida")),
    ("gross_margin", ("gross_margin", "gross_margin_pct")),
    ("operating_margin", ("operating_margin", "ebit_margin")),
    ("payout_ratio", ("payout_ratio", "payout")),
    ("book_value_per_share", ("book_value_per_share", "vpa", "book_value")),
    ("earnings_per_share", ("earnings_per_share", "lpa")),
    ("debt_to_equity", ("debt_to_equity", "debt_equity")),
    ("current_ratio", ("current_ratio",)),
    ("enterprise_to_ebitda", ("enterprise_to_ebitda", "ev_ebitda")),
    ("ebitda", ("ebitda",)),
    ("total_revenue", ("total_revenue", "revenue", "net_revenue")),
    ("revenue_growth", ("revenue_growth", "revenue_growth_pct", "cagr_revenue_5y")),
    ("earnings_growth", ("earnings_growth", "cagr_earnings_5y")),
    ("total_cash", ("total_cash", "cash")),
    ("total_debt", ("total_debt", "debt")),
    ("free_cashflow", ("free_cashflow", "fcf")),
)


def fundamentals_updates_from_bolsai(payload: dict) -> dict[str, object]:
    """Extrai campos não-nulos do payload Bolsai para merge em StockFundamentals."""
    if not payload:
        return {}
    updates: dict[str, object] = {}
    for target, sources in _FUNDAMENTALS_MAP:
        value = _float(payload, *sources)
        if value is not None:
            updates[target] = value
    return updates


def merge_bolsai_fundamentals(
    fundamentals: StockFundamentals,
    payload: dict,
) -> StockFundamentals:
    updates = fundamentals_updates_from_bolsai(payload)
    if not updates:
        return fundamentals
    return fundamentals.model_copy(update=updates)


def bolsai_quote_updates(quote: dict | None, *, fundamentals: dict | None = None) -> dict[str, object]:
    """Cotação B3/Bolsai para alinhar preço com fundamentos (estilo Investidor10)."""
    updates: dict[str, object] = {}

    price = None
    if quote:
        price = _float(quote, "close", "close_price", "price", "last_price")
        change = _float(quote, "change_percent", "change_pct", "variation_percent")
        previous_close = _float(
            quote,
            "previous_close",
            "prev_close",
            "previous_close_price",
            "yesterday_close",
            "fechamento_anterior",
        )
        if price is not None and price > 0:
            updates["price"] = price
        if previous_close is not None:
            updates["previous_close"] = previous_close
        if change is not None:
            updates["change_percent"] = change
        elif price is not None and previous_close is not None and previous_close > 0:
            updates["change_percent"] = round(((price / previous_close) - 1) * 100, 2)

    if "price" not in updates and fundamentals:
        close = _float(fundamentals, "close_price", "close", "price")
        if close is not None and close > 0:
            updates["price"] = close

    return updates


def merge_bolsai_market_stats(
    market_stats: StockMarketStats,
    *,
    fundamentals: dict | None = None,
    quote: dict | None = None,
) -> StockMarketStats:
    """Enriquece pregão/capitalização com /fundamentals e /stocks/{ticker}/quote."""
    updates: dict[str, object] = {}

    if fundamentals:
        market_cap = _float(fundamentals, "market_cap")
        if market_cap is not None:
            updates["market_cap"] = market_cap
        close = _float(fundamentals, "close_price")
        lpa = _float(fundamentals, "lpa")
        pl = _float(fundamentals, "pl", "price_earnings", "pe")
        if pl is not None:
            updates["price_earnings"] = pl
        if lpa is not None:
            updates["earnings_per_share"] = lpa

    if quote:
        for target, sources in (
            ("open", ("open",)),
            ("day_high", ("high",)),
            ("day_low", ("low",)),
            ("volume", ("volume",)),
        ):
            for source in sources:
                value = _float(quote, source)
                if value is not None:
                    updates[target] = value
                    break
        previous_close = _float(
            quote,
            "previous_close",
            "prev_close",
            "previous_close_price",
            "yesterday_close",
            "fechamento_anterior",
        )
        if previous_close is not None:
            updates["previous_close"] = previous_close
    if not updates:
        return market_stats
    return market_stats.model_copy(update=updates)
