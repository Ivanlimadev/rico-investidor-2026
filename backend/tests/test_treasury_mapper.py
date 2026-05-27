from app.clients.brapi.treasury_mapper import (
    map_treasury_bond,
    map_treasury_history,
    map_treasury_list,
    normalize_treasury_symbol,
)


def test_normalize_treasury_symbol():
    assert normalize_treasury_symbol(" TESOURO-SELIC-01032031 ") == "tesouro-selic-01032031"


def test_map_treasury_bond():
    payload = {
        "symbol": "tesouro-selic-01032031",
        "bondType": "Tesouro Selic",
        "indexer": "selic",
        "couponType": "zero",
        "maturityDate": "2031-03-01",
        "durationDays": 1741,
        "baseDate": "2026-05-25",
        "buyRate": 0.08,
        "sellRate": 0.09,
        "buyPrice": 19008.53,
        "sellPrice": 18989.29,
        "basePrice": 18989.29,
        "rateInfo": {
            "rateType": "spreadOverSelic",
            "rateUnit": "% a.a.",
            "description": "Spread sobre Selic",
        },
    }

    result = map_treasury_bond(payload)

    assert result.symbol == "tesouro-selic-01032031"
    assert result.bond_type == "Tesouro Selic"
    assert result.sell_price == 18989.29
    assert result.rate_info is not None
    assert result.rate_info.rate_type == "spreadOverSelic"


def test_map_treasury_list():
    payload = {
        "results": [
            {
                "symbol": "tesouro-selic-01032031",
                "bondType": "Tesouro Selic",
                "indexer": "selic",
            }
        ],
        "pagination": {
            "page": 1,
            "limit": 30,
            "totalItems": 42,
            "totalPages": 2,
        },
    }

    result = map_treasury_list(payload, group="selic")

    assert result.total == 42
    assert result.total_pages == 2
    assert result.items[0].symbol == "tesouro-selic-01032031"


def test_map_treasury_history():
    payload = {
        "results": [
            {
                "symbol": "tesouro-selic-01032031",
                "bondType": "Tesouro Selic",
                "indexer": "selic",
                "history": [
                    {
                        "baseDate": "2026-04-29",
                        "buyRate": 0.08,
                        "sellRate": 0.09,
                        "buyPrice": 18832.19,
                        "sellPrice": 18812.82,
                        "basePrice": 18812.82,
                    },
                    {
                        "baseDate": "2026-04-30",
                        "buyRate": 0.08,
                        "sellRate": 0.09,
                        "buyPrice": 18842.4,
                        "sellPrice": 18823.2,
                        "basePrice": 18823.2,
                    },
                ],
            }
        ]
    }

    result = map_treasury_history(payload, symbol="tesouro-selic-01032031", limit=252)

    assert result.symbol == "tesouro-selic-01032031"
    assert result.count == 2
    assert result.history[0].date == "2026-04-29"
    assert result.history[1].base_price == 18823.2
