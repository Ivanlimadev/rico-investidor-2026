from app.clients.bolsai.fundamentals_mapper import bolsai_quote_updates


def test_bolsai_quote_updates_prefers_live_quote():
    updates = bolsai_quote_updates(
        {
            "close": 10.52,
            "previous_close": 10.80,
            "change_percent": -2.59,
        }
    )
    assert updates["price"] == 10.52
    assert updates["previous_close"] == 10.80
    assert updates["change_percent"] == -2.59


def test_bolsai_quote_updates_falls_back_to_fundamentals_close():
    updates = bolsai_quote_updates(
        None,
        fundamentals={"close_price": 10.52},
    )
    assert updates == {"price": 10.52}
