"""Matriz de decisão Bolsai vs Brapi — melhor fonte por domínio de dado."""

from __future__ import annotations

# Domínios onde a Bolsai é primária (TTM CVM/B3, estilo Investidor10).
BOLSAI_PRIMARY = frozenset(
    {
        "stock_dividends",
        "fii_distributions",
        "dividend_yield_ttm",
        "fundamentals_ratios_ttm",
        "fundamental_history_ttm",
        "stock_candles_long_adjusted",
        "corporate_events",
        "macro_cdi",
        "fii_operational_metrics",
        "company_registry",
        "fii_screener",
    }
)

# Domínios onde a Brapi permanece primária (cotação ao vivo, Yahoo modules, v2 FII).
BRAPI_PRIMARY = frozenset(
    {
        "live_quote",
        "sparklines",
        "stock_profile",
        "market_stats",
        "analyst_consensus",
        "beta_forward_pe",
        "financial_statements",
        "fii_cvm_reports",
        "fii_candles",
        "fii_catalog_screener",
        "currency_treasury_indices",
        "macro_selic_ipca_point",
    }
)

LONG_CANDLE_RANGES = frozenset({"5y", "10y", "15y", "max"})
LONG_CANDLE_MIN_LIMIT = 1260  # ~5 anos de pregões

BOLSAI_SCREENER_SORTS = frozenset(
    {
        "dividend_yield",
        "price_earnings",
        "return_on_equity",
        "price_to_book",
        "market_cap",
    }
)


def prefer_bolsai_screener(
    *,
    quote_type: str,
    sort_by: str,
    sector: str | None,
    min_dividend_yield: float | None = None,
    max_dividend_yield: float | None = None,
    min_price_earnings: float | None = None,
    max_price_earnings: float | None = None,
    min_return_on_equity: float | None = None,
    max_return_on_equity: float | None = None,
    min_price_to_book: float | None = None,
    max_price_to_book: float | None = None,
) -> bool:
    """Screener fundamentalista: Bolsai nativo; volume/setor: Brapi."""
    if quote_type.strip().lower() != "stock":
        return False
    if sector and sector.strip():
        return False
    has_fund_filters = any(
        value is not None
        for value in (
            min_dividend_yield,
            max_dividend_yield,
            min_price_earnings,
            max_price_earnings,
            min_return_on_equity,
            max_return_on_equity,
            min_price_to_book,
            max_price_to_book,
        )
    )
    sort = sort_by.strip().lower()
    if sort == "volume" and not has_fund_filters:
        return False
    return sort in BOLSAI_SCREENER_SORTS or has_fund_filters


def prefer_bolsai_candles(*, range_: str | None, limit: int) -> bool:
    """Histórico longo ajustado: Bolsai COTAHIST; curto: Brapi."""
    if range_ and range_.strip().lower() in LONG_CANDLE_RANGES:
        return True
    return limit >= LONG_CANDLE_MIN_LIMIT


def hybrid_provider_label(*, bolsai_used: bool, brapi_used: bool) -> str:
    if bolsai_used and brapi_used:
        return "hybrid"
    if bolsai_used:
        return "bolsai"
    return "brapi"
