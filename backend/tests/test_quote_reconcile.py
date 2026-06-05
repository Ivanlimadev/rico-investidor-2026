from app.clients.brapi.models import MarketQuote
from app.domain.global_markets.models import GlobalStockCandle
from app.domain.global_markets.quote_reconcile import reconcile_quote_with_candles


def test_reconcile_quote_with_candles_aligns_price_and_change():
    quote = MarketQuote(
        symbol="AAPL",
        name="Apple",
        price=100.0,
        change_percent=0.0,
        category="stocks",
        provider="marketstack",
    )
    candles = [
        GlobalStockCandle(date="2025-01-01", close=90.0, open=89.0, high=91.0, low=88.0, volume=1_000),
        GlobalStockCandle(date="2025-01-02", close=100.0, open=99.0, high=101.0, low=98.0, volume=2_000),
    ]

    reconciled = reconcile_quote_with_candles(quote, candles)

    assert reconciled.price == 100.0
    assert reconciled.previous_close == 90.0
    assert abs(reconciled.change_percent - 11.11) < 0.02
    assert reconciled.volume == 2_000
    assert reconciled.session_date == "2025-01-02"


def test_reconcile_quote_skips_trailing_zero_candles():
    quote = MarketQuote(
        symbol="META",
        name="Meta",
        price=0.0,
        change_percent=0.0,
        category="stocks",
        provider="marketstack",
    )
    candles = [
        GlobalStockCandle(date="2026-06-02", close=597.63),
        GlobalStockCandle(date="2026-06-03", close=622.98),
        GlobalStockCandle(date="2026-06-04", close=0.0, adj_close=0.0),
    ]

    reconciled = reconcile_quote_with_candles(quote, candles)

    assert reconciled.price == 622.98
    assert reconciled.previous_close == 597.63
    assert reconciled.session_date == "2026-06-03"
