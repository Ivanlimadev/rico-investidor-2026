from app.clients.bolsai.fii_screener_mapper import (
    build_bolsai_fii_screener_params,
    map_bolsai_fii_screener,
    map_bolsai_fii_screener_row,
)
from app.clients.brapi.fii_catalog import ScreenerFilters


def test_map_bolsai_fii_screener_row():
    row = {
        "ticker": "HGLG11",
        "name": "Pátria Log",
        "segment": "Logística",
        "dividend_yield_ttm": 7.27,
        "pvp": 0.92,
        "vacancy_pct": 3.2,
    }
    item = map_bolsai_fii_screener_row(row)
    assert item is not None
    assert item.ticker == "HGLG11"
    assert item.dividend_yield_ttm == 7.27
    assert item.provider == "bolsai"


def test_build_bolsai_fii_screener_params_maps_filters():
    filters = ScreenerFilters(
        limit=25,
        offset=50,
        sort="pvp",
        order="asc",
        dividend_yield_ttm_gt=8.0,
        vacancy_pct_lt=5.0,
        segment="Logística",
    )
    params = build_bolsai_fii_screener_params(filters)
    assert params["sort"] == "pvp"
    assert params["dividend_yield_ttm_gt"] == 8.0
    assert params["vacancy_pct_lt"] == 5.0
    assert params["segment"] == "Logística"


def test_map_bolsai_fii_screener_applies_search_filter():
    payload = {
        "total": 2,
        "data": [
            {"ticker": "HGLG11", "name": "Pátria Log", "dividend_yield_ttm": 7.0, "pvp": 0.9},
            {"ticker": "MXRF11", "name": "Maxi Renda", "dividend_yield_ttm": 11.0, "pvp": 1.0},
        ],
    }
    filters = ScreenerFilters(limit=10, offset=0, search="hglg")
    result = map_bolsai_fii_screener(payload, filters=filters)
    assert result.count == 1
    assert result.data[0].ticker == "HGLG11"
    assert result.provider == "hybrid"
