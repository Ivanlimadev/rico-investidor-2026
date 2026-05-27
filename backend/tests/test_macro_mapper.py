from app.clients.brapi.macro_mapper import map_brazil_macro, map_dictionary


def test_map_brazil_macro():
    result = map_brazil_macro(
        prime_rate_data={"prime-rate": [{"date": "27/05/2026", "value": 14.5}]},
        inflation_data={"inflation": [{"date": "01/04/2026", "value": 4.39}]},
    )

    assert result.selic == 14.5
    assert result.selic_as_of == "27/05/2026"
    assert result.ipca_12m == 4.39
    assert result.ipca_as_of == "01/04/2026"


def test_map_dictionary():
    result = map_dictionary(
        {
            "fields": [
                {
                    "key": "priceToBook",
                    "label": "P/VP",
                    "description": "Preço sobre valor patrimonial",
                    "category": "statistics",
                }
            ]
        },
        category="statistics",
    )

    assert result.count == 1
    assert result.fields[0].key == "priceToBook"
    assert result.fields[0].description == "Preço sobre valor patrimonial"
