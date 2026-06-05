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
        for target, source in (
            ("open", "open"),
            ("day_high", "high"),
            ("day_low", "low"),
            ("previous_close", "close"),
            ("volume", "volume"),
        ):
            value = _float(quote, source)
            if value is not None:
                updates[target] = value
    if not updates:
        return market_stats
    return market_stats.model_copy(update=updates)
