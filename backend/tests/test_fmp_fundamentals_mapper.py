from app.clients.brapi.models import StockFundamentals
from app.clients.fmp.fundamentals_mapper import map_fundamentals_from_fmp


def test_map_fundamentals_from_fmp_fills_missing_only():
    base = StockFundamentals(
        dividend_yield_12m=0.34,
        price_earnings=None,
        provider="marketstack",
    )
    ratios = {
        "priceToEarningsRatioTTM": 32.5,
        "returnOnEquityTTM": 1.496,
        "netProfitMarginTTM": 0.245,
        "priceToBookRatioTTM": 45.2,
        "dividendYieldTTM": 0.005,
    }

    merged = map_fundamentals_from_fmp(base, profile=None, ratios_ttm=ratios, price=310.0)

    assert merged.dividend_yield_12m == 0.34
    assert merged.price_earnings == 32.5
    assert merged.return_on_equity == 149.6
    assert merged.profit_margin == 24.5
    assert merged.price_to_book == 45.2
    assert merged.provider == "marketstack+fmp"


def test_map_fundamentals_uses_key_metrics_for_roe():
    base = StockFundamentals(provider="marketstack")
    metrics = {"returnOnEquityTTM": 1.466, "returnOnAssetsTTM": 0.33}

    merged = map_fundamentals_from_fmp(
        base,
        profile=None,
        ratios_ttm={"netProfitMarginTTM": 0.27},
        key_metrics_ttm=metrics,
    )

    assert merged.return_on_equity == 146.6
    assert merged.return_on_assets == 33.0
    assert merged.profit_margin == 27.0


def test_map_fundamentals_from_profile_pe_and_eps():
    base = StockFundamentals(provider="marketstack")
    profile = {"pe": 28.0, "eps": 6.5, "beta": 1.21}

    merged = map_fundamentals_from_fmp(base, profile=profile, ratios_ttm=None, price=200.0)

    assert merged.price_earnings == 28.0
    assert merged.earnings_per_share == 6.5
    assert merged.beta == 1.21
