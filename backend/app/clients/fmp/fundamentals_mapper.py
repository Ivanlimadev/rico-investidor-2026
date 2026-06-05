from __future__ import annotations

from app.clients.brapi.models import StockFundamentals
from app.domain.global_markets.fundamentals import _as_pct, _safe_float, _valid_ratio


def _fmp_ratio_to_pct(value: object) -> float | None:
    """Converte razões FMP (0.24 ou 1.52) para percentual exibido (24 ou 152)."""
    parsed = _safe_float(value)
    if parsed is None:
        return None
    if abs(parsed) <= 1:
        return round(parsed * 100, 2)
    if abs(parsed) < 15:
        return round(parsed * 100, 2)
    return round(parsed, 2)


def _first_float(payload: dict | None, *keys: str) -> float | None:
    if not payload:
        return None
    for key in keys:
        value = _safe_float(payload.get(key))
        if value is not None:
            return value
    return None


def map_fundamentals_from_fmp(
    fundamentals: StockFundamentals,
    *,
    profile: dict | None,
    ratios_ttm: dict | None,
    key_metrics_ttm: dict | None = None,
    price: float | None = None,
) -> StockFundamentals:
    """Preenche lacunas com FMP (perfil + ratios TTM) — padrão Yahoo/Morningstar.

    Prioridade: mantém valores já vindos da Marketstack tickerinfo; só preenche ``None``.
    DY calculado por proventos (TTM/preço) não é sobrescrito pelo yield estático da FMP.
    """
    if not profile and not ratios_ttm and not key_metrics_ttm:
        return fundamentals

    updates: dict[str, object] = {}
    ratios = ratios_ttm or {}
    metrics = key_metrics_ttm or {}
    prof = profile or {}

    pe = _valid_ratio(
        _first_float(
            ratios,
            "priceToEarningsRatioTTM",
            "peRatioTTM",
            "priceEarningsRatio",
            "priceEarningsRatioTTM",
        )
        or _first_float(prof, "pe", "peRatio", "priceEarnings")
    )
    if fundamentals.price_earnings is None and pe is not None:
        updates["price_earnings"] = pe

    pb = _valid_ratio(
        _first_float(
            ratios,
            "priceToBookRatioTTM",
            "priceToBookRatio",
            "pbRatioTTM",
        )
        or _first_float(prof, "priceToBook", "pbRatio")
    )
    if fundamentals.price_to_book is None and pb is not None:
        updates["price_to_book"] = pb

    roe = _fmp_ratio_to_pct(
        _first_float(
            metrics,
            "returnOnEquityTTM",
            "returnOnEquity",
        )
        or _first_float(
            ratios,
            "returnOnEquityTTM",
            "returnOnEquity",
            "roeTTM",
        )
    )
    if fundamentals.return_on_equity is None and roe is not None:
        updates["return_on_equity"] = roe

    roa = _fmp_ratio_to_pct(
        _first_float(metrics, "returnOnAssetsTTM", "returnOnAssets")
        or _first_float(ratios, "returnOnAssetsTTM", "returnOnAssets")
    )
    if fundamentals.return_on_assets is None and roa is not None:
        updates["return_on_assets"] = roa

    margin = _fmp_ratio_to_pct(
        _first_float(
            ratios,
            "netProfitMarginTTM",
            "netProfitMargin",
            "profitMarginTTM",
        )
    )
    if fundamentals.profit_margin is None and margin is not None:
        updates["profit_margin"] = margin

    gross = _as_pct(_first_float(ratios, "grossProfitMarginTTM", "grossProfitMargin"))
    if fundamentals.gross_margin is None and gross is not None:
        updates["gross_margin"] = gross

    operating = _as_pct(_first_float(ratios, "operatingProfitMarginTTM", "operatingProfitMargin"))
    if fundamentals.operating_margin is None and operating is not None:
        updates["operating_margin"] = operating

    payout = _as_pct(_first_float(ratios, "payoutRatioTTM", "payoutRatio"))
    if fundamentals.payout_ratio is None and payout is not None:
        updates["payout_ratio"] = payout

    fmp_dy = _as_pct(_first_float(ratios, "dividendYieldTTM", "dividendYield", "dividendYielTTM"))
    if fundamentals.dividend_yield_12m is None and fmp_dy is not None:
        updates["dividend_yield_12m"] = fmp_dy

    beta = _first_float(ratios, "beta", "betaTTM") or _first_float(prof, "beta")
    if fundamentals.beta is None and beta is not None:
        updates["beta"] = round(beta, 4)

    eps = _first_float(prof, "eps", "epsTTM") or _first_float(ratios, "netIncomePerShareTTM")
    if fundamentals.earnings_per_share is None and eps is not None:
        updates["earnings_per_share"] = round(eps, 4)
    elif (
        fundamentals.earnings_per_share is None
        and fundamentals.price_earnings is None
        and pe is not None
        and price is not None
        and price > 0
    ):
        updates["earnings_per_share"] = round(price / pe, 4)

    book = _first_float(prof, "bookValue", "bookValuePerShare")
    if fundamentals.book_value_per_share is None and book is not None:
        updates["book_value_per_share"] = round(book, 4)

    forward_pe = _valid_ratio(_first_float(ratios, "priceToEarningsGrowthRatioTTM", "forwardPE"))
    if fundamentals.forward_pe is None and forward_pe is not None:
        updates["forward_pe"] = forward_pe

    debt_eq = _first_float(ratios, "debtEquityRatioTTM", "debtEquityRatio")
    if fundamentals.debt_to_equity is None and debt_eq is not None:
        updates["debt_to_equity"] = round(debt_eq, 2)

    current = _first_float(ratios, "currentRatioTTM", "currentRatio")
    if fundamentals.current_ratio is None and current is not None:
        updates["current_ratio"] = round(current, 2)

    if not updates:
        return fundamentals

    provider = fundamentals.provider
    if provider == "marketstack" or not provider:
        provider = "marketstack+fmp"
    return fundamentals.model_copy(update={**updates, "provider": provider})
