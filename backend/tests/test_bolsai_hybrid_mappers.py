from app.clients.bolsai.corporate_mapper import map_bolsai_corporate_actions
from app.clients.bolsai.fii_mapper import map_fii_detail_from_bolsai
from app.clients.bolsai.fundamentals_mapper import (
    fundamentals_updates_from_bolsai,
    merge_bolsai_fundamentals,
    merge_bolsai_market_stats,
)
from app.clients.bolsai.history_mapper import (
    map_bolsai_fundamental_history,
    map_bolsai_stock_candles,
)
from app.clients.bolsai.macro_mapper import merge_bolsai_macro
from app.clients.brapi.models import BrazilMacroResponse, StockFundamentals, StockMarketStats
from app.domain.quotes.hybrid_br_sources import prefer_bolsai_candles


def test_merge_bolsai_fundamentals_uses_native_pl_and_net_revenue():
    base = StockFundamentals()
    merged = merge_bolsai_fundamentals(
        base,
        {
            "pl": 4.94,
            "pvp": 1.19,
            "roe": 24.17,
            "net_revenue": 498091000.0,
            "ev_ebitda": 3.96,
            "cagr_revenue_5y": 12.83,
        },
    )
    assert merged.price_earnings == 4.94
    assert merged.price_to_book == 1.19
    assert merged.total_revenue == 498091000.0
    assert merged.enterprise_to_ebitda == 3.96
    assert merged.revenue_growth == 12.83
    assert "enterprise_value" not in fundamentals_updates_from_bolsai({"market_cap": 999})


def test_map_bolsai_stock_candles_uses_trade_date_and_adjusted_close():
    result = map_bolsai_stock_candles(
        "PETR4",
        {
            "prices": [
                {
                    "trade_date": "2026-06-03",
                    "open": 41.65,
                    "high": 41.87,
                    "low": 41.25,
                    "close": 41.25,
                    "adjusted_close": 41.25,
                    "volume": 42895100,
                }
            ]
        },
        limit=10,
    )
    assert result.count == 1
    assert result.candles[0].close == 41.25


def test_map_bolsai_fundamental_history_uses_reference_date_and_pl():
    result = map_bolsai_fundamental_history(
        "PETR4",
        {
            "history": [
                {
                    "reference_date": "2026-03-31",
                    "net_revenue": 498091000.0,
                    "roe": 24.17,
                    "pl": 4.94,
                    "pvp": 1.19,
                    "net_margin": 21.69,
                }
            ]
        },
        limit=4,
    )
    assert result.periods[0].end_date == "2026-03-31"
    assert result.periods[0].total_revenue == 498091000.0
    assert result.periods[0].price_earnings == 4.94
    assert result.periods[0].profit_margin == 21.69


def test_merge_bolsai_macro_converts_daily_selic_and_ipca_12m():
    base = BrazilMacroResponse(selic=14.0, provider="brapi")
    merged = merge_bolsai_macro(
        base,
        selic={"data": [{"date": "2026-06-03", "value": 0.0534}]},
        cdi={"data": [{"date": "2026-06-03", "value": 0.0534}]},
        ipca={
            "data": [
                {"date": "2026-04-01", "value": 0.67},
                {"date": "2026-03-01", "value": 0.88},
                {"date": "2026-02-01", "value": 0.7},
                {"date": "2026-01-01", "value": 0.33},
                {"date": "2025-12-01", "value": 0.33},
                {"date": "2025-11-01", "value": 0.18},
                {"date": "2025-10-01", "value": 0.09},
                {"date": "2025-09-01", "value": 0.48},
                {"date": "2025-08-01", "value": -0.11},
                {"date": "2025-07-01", "value": 0.26},
                {"date": "2025-06-01", "value": 0.24},
                {"date": "2025-05-01", "value": 0.26},
            ]
        },
    )
    assert merged.selic == 13.46
    assert merged.cdi == 13.46
    assert merged.ipca_12m is not None
    assert merged.provider == "hybrid"


def test_map_fii_detail_from_bolsai_full_payload():
    detail = map_fii_detail_from_bolsai(
        {
            "ticker": "HGLG11",
            "name": "HGLG11",
            "pvp": 0.92,
            "vacancy_pct": 3.23,
            "fund_type": "Tijolo",
            "asset_composition": {"real_estate_leased_pct": 83.73, "cash_pct": 1.09},
            "fees_paid_last_month": {"admin": 100.0, "performance": 0.0},
            "top_properties": [{"name": "Galpão A", "area_sqm": 1000.0}],
        }
    )
    assert detail is not None
    assert detail.pvp == 0.92
    assert detail.asset_composition is not None
    assert detail.asset_composition.real_estate_leased_pct == 83.73
    assert detail.fees_paid_last_month is not None
    assert detail.top_properties[0].name == "Galpão A"


def test_merge_bolsai_market_stats():
    stats = merge_bolsai_market_stats(
        StockMarketStats(),
        fundamentals={"market_cap": 100.0, "pl": 5.0, "lpa": 2.0},
        quote={"open": 10.0, "high": 11.0, "low": 9.5, "close": 10.5, "volume": 1000},
    )
    assert stats.market_cap == 100.0
    assert stats.price_earnings == 5.0
    assert stats.open == 10.0


def test_map_bolsai_corporate_actions():
    actions = map_bolsai_corporate_actions(
        {
            "events": [
                {
                    "type": "SPLIT",
                    "factor": 0.5,
                    "date": "2008-04-28",
                    "ratio_from": 1,
                    "ratio_to": 2,
                }
            ]
        }
    )
    assert actions[0].label == "SPLIT"
    assert actions[0].ex_date == "2008-04-28"


def test_prefer_bolsai_candles():
    assert prefer_bolsai_candles(range_="5y", limit=252)
    assert prefer_bolsai_candles(range_=None, limit=2000)
    assert not prefer_bolsai_candles(range_="1y", limit=252)
