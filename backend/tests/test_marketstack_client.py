from app.clients.marketstack.client import MarketstackClient


def test_exchange_ticker_rows_from_nested_payload():
    payload = {
        "pagination": {"limit": 3, "offset": 0, "count": 3, "total": 10183},
        "data": {
            "name": "NASDAQ - ALL MARKETS",
            "mic": "XNAS",
            "tickers": [
                {"name": "Microsoft Corporation", "symbol": "MSFT", "has_eod": True},
                {"name": "Apple Inc", "symbol": "AAPL", "has_eod": True},
            ],
        },
    }

    rows = MarketstackClient._exchange_ticker_rows(payload)

    assert len(rows) == 2
    assert rows[0]["symbol"] == "MSFT"
    assert rows[1]["symbol"] == "AAPL"
