from app.clients.marketstack.stock_mapper import sparklines_from_eod_items


def test_sparklines_from_eod_items_orders_and_caps():
    rows = [
        {"symbol": "AAPL", "date": "2026-05-20", "close": 190.0},
        {"symbol": "AAPL", "date": "2026-05-21", "close": 192.0},
        {"symbol": "AAPL", "date": "2026-05-22", "close": 195.0},
        {"symbol": "MSFT", "date": "2026-05-22", "close": 420.0},
    ]

    result = sparklines_from_eod_items(rows, max_points=24)

    assert result["AAPL"] == [190.0, 192.0, 195.0]
    assert "MSFT" not in result
