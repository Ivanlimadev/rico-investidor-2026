from app.clients.brapi.models import MarketQuote
from app.domain.quotes.br_quote_reconcile import merge_bolsai_fundamentals_into_quote


def test_merge_preserves_zero_dividend_yield():
    quote = MarketQuote(
        symbol="BRKM5",
        name="Braskem",
        price=9.75,
        change_percent=-1.2,
        category="acoes_br",
        dividend_yield_12m=7.65,
    )
    merged = merge_bolsai_fundamentals_into_quote(
        quote,
        fundamentals={"pl": -0.92, "pvp": -0.53, "dividend_yield": 7.65},
        bolsai_quote={"close": 10.52, "previous_close": 10.80},
        display_dividend_yield=0.0,
    )
    assert merged.price == 10.52
    assert merged.dividend_yield_12m == 0.0
    assert merged.price_to_book == -0.53
