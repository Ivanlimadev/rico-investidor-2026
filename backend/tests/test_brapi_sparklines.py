from app.clients.brapi.stock_mapper import sparkline_from_price_points


def test_sparkline_from_brapi_price_points_unix():
    points = [
        {"date": 1_700_000_000, "close": 10.0},
        {"date": 1_700_086_400, "close": 11.5},
        {"date": 1_700_172_800, "close": 12.0},
    ]

    spark = sparkline_from_price_points(points)

    assert spark == [10.0, 11.5, 12.0]


def test_sparkline_from_brapi_price_points_iso():
    points = [
        {"date": "2024-01-02", "close": 20.0},
        {"date": "2024-01-03T00:00:00Z", "close": 21.0},
    ]

    assert sparkline_from_price_points(points) == [20.0, 21.0]

