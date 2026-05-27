from app.clients.brapi.index_mapper import map_index_quote, normalize_index_symbol


def test_normalize_index_symbol():
    assert normalize_index_symbol("ibov") == "^BVSP"
    assert normalize_index_symbol("^BVSP") == "^BVSP"
    assert normalize_index_symbol("ifix") == "IFIX"


def test_map_index_quote():
    preset = type("Preset", (), {"symbol": "^BVSP", "name": "Ibovespa", "group": "brasil"})()
    payload = {
        "symbol": "^BVSP",
        "longName": "IBOVESPA",
        "regularMarketPrice": 128450.0,
        "regularMarketChangePercent": 0.67,
        "regularMarketDayHigh": 129000.0,
        "regularMarketDayLow": 127800.0,
    }

    result = map_index_quote(payload, preset=preset)

    assert result.symbol == "^BVSP"
    assert result.name == "Ibovespa"
    assert result.group == "brasil"
    assert result.price == 128450.0
    assert result.change_percent == 0.67
