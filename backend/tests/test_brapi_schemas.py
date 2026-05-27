import pytest

from app.clients.brapi.schema_validation import (
    parse_fii_dividends,
    parse_fii_indicator_item,
    parse_fii_indicators_response,
    parse_list_stocks,
    parse_quote_item,
    parse_quote_response,
)
from app.clients.brapi.stock_mapper import map_market_quote, map_screener_item
from app.core.exceptions import UpstreamError


def test_parse_quote_response_maps_to_market_quote():
    payload = {
        "results": [
            {
                "symbol": "PETR4",
                "longName": "Petrobras",
                "regularMarketPrice": 43.44,
                "regularMarketChangePercent": 0.09,
                "type": "stock",
                "logourl": "https://icons.brapi.dev/icons/PETR4.svg",
            }
        ]
    }

    items = parse_quote_response(payload)
    quote = map_market_quote(items[0])

    assert quote.symbol == "PETR4"
    assert quote.price == 43.44


def test_parse_quote_item_not_found():
    with pytest.raises(UpstreamError) as exc:
        parse_quote_item({"results": []})
    assert exc.value.status_code == 404


def test_parse_list_stocks_for_screener():
    payload = {
        "stocks": [
            {
                "stock": "VALE3",
                "name": "Vale",
                "close": 62.1,
                "change": -0.4,
                "type": "stock",
                "sector": "Non-Energy Minerals",
            }
        ],
        "totalCount": 1,
    }

    stocks = parse_list_stocks(payload)
    item = map_screener_item(stocks[0])

    assert item.symbol == "VALE3"
    assert item.sector == "Non-Energy Minerals"


def test_parse_fii_indicators_response():
    payload = {
        "fiis": [
            {
                "symbol": "HGLG11",
                "name": "CSHG Logística",
                "price": 154.7,
                "dividendYield12m": 0.0853,
            }
        ]
    }

    items = parse_fii_indicators_response(payload)
    assert items[0]["symbol"] == "HGLG11"
    assert parse_fii_indicator_item(payload)["name"] == "CSHG Logística"


def test_parse_fii_dividends():
    payload = {
        "dividends": [
            {
                "symbol": "HGLG11",
                "rate": 1.02,
                "lastDatePrior": "2026-03-28",
                "paymentDate": "2026-04-07",
            }
        ]
    }

    items = parse_fii_dividends(payload)
    assert len(items) == 1
    assert items[0]["rate"] == 1.02


def test_invalid_envelope_raises_upstream_error():
    with pytest.raises(UpstreamError) as exc:
        parse_quote_response({"results": "not-a-list"})
    assert exc.value.status_code == 502
