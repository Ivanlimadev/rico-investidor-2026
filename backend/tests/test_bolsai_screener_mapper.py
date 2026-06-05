from app.clients.bolsai.screener_mapper import build_bolsai_screener_params, map_bolsai_screener
from app.domain.quotes.hybrid_br_sources import prefer_bolsai_screener


def test_build_bolsai_screener_params_maps_filters():
    params = build_bolsai_screener_params(
        sort_by="dividend_yield",
        sort_order="desc",
        limit=25,
        page=2,
        min_dividend_yield=4.0,
        max_price_earnings=12.0,
    )
    assert params["sort"] == "dy"
    assert params["limit"] == 25
    assert params["offset"] == 25
    assert params["dy_gt"] == 4.0
    assert params["pl_lt"] == 12.0


def test_map_bolsai_screener_maps_rows():
    payload = {
        "total": 2,
        "data": [
            {
                "ticker": "PETR4",
                "corporate_name": "Petrobras",
                "close_price": 35.5,
                "dividend_yield": 8.2,
                "pl": 5.1,
                "roe": 22.0,
                "pvp": 1.2,
                "market_cap": 500000000000.0,
                "sector": "Petróleo",
            },
            {
                "ticker": "VALE3",
                "corporate_name": "Vale",
                "close_price": 60.0,
                "dividend_yield": 6.0,
                "pl": 7.0,
                "roe": 18.0,
                "pvp": 1.5,
                "market_cap": 250000000000.0,
                "sector": "Mineração",
            },
        ],
    }
    result = map_bolsai_screener(payload, page=1, limit=50, search="petr")
    assert result.count == 1
    assert result.items[0].symbol == "PETR4"
    assert result.items[0].dividend_yield_12m == 8.2
    assert result.items[0].provider == "bolsai"
    assert result.provider == "hybrid"


def test_prefer_bolsai_screener_rules():
    assert prefer_bolsai_screener(quote_type="stock", sort_by="volume", sector=None) is False
    assert prefer_bolsai_screener(
        quote_type="stock",
        sort_by="volume",
        sector=None,
        min_dividend_yield=5.0,
    )
    assert prefer_bolsai_screener(quote_type="stock", sort_by="dividend_yield", sector=None)
    assert not prefer_bolsai_screener(quote_type="stock", sort_by="dividend_yield", sector="Bancos")
