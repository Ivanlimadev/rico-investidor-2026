from app.clients.brapi.currency_mapper import (
    map_available_pairs,
    map_currency_history,
    map_currency_rates,
    normalize_currency_pair,
)


def test_normalize_currency_pair():
    assert normalize_currency_pair("usd/brl") == "USD-BRL"
    assert normalize_currency_pair(" EUR-BRL ") == "EUR-BRL"


def test_map_currency_rates():
    payload = {
        "currency": [
            {
                "fromCurrency": "USD",
                "toCurrency": "BRL",
                "name": "Dólar Americano/Real Brasileiro",
                "high": "5.34",
                "low": "5.20",
                "bidVariation": "-0.05",
                "percentageChange": "-1.03",
                "bidPrice": "5.2159",
                "askPrice": "5.2189",
                "updatedAtDate": "2026-02-06 19:02:28",
            }
        ]
    }

    result = map_currency_rates(payload)

    assert result.count == 1
    assert result.items[0].pair == "USD-BRL"
    assert result.items[0].bid_price == 5.2159
    assert result.items[0].change_percent == -1.03


def test_map_available_pairs():
    payload = {
        "currencies": [
            {"name": "USD-BRL", "currency": "Dólar Americano/Real Brasileiro"},
            {"name": "EUR-USD", "currency": "Euro/Dólar Americano"},
        ]
    }

    result = map_available_pairs(payload)

    assert result.count == 2
    assert result.pairs[0].pair == "USD-BRL"


def test_map_currency_history():
    payload = {
        "results": [
            {
                "pair": "USD-BRL",
                "fromCurrency": "USD",
                "toCurrency": "BRL",
                "observations": [
                    {"date": "2026-04-30", "value": 4.9886},
                    {"date": "2026-04-29", "value": 4.9712},
                ],
            }
        ]
    }

    result = map_currency_history(payload, pair="USD-BRL")

    assert result.pair == "USD-BRL"
    assert result.count == 2
    assert result.history[0].date == "2026-04-29"
    assert result.history[1].value == 4.9886
