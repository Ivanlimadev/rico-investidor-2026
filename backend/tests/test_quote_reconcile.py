from datetime import datetime
from zoneinfo import ZoneInfo

from app.clients.brapi.models import MarketQuote
from app.domain.global_markets.models import GlobalStockCandle
from app.domain.global_markets.quote_reconcile import (
    reconcile_quote_with_candles,
    reconcile_quotes_from_eod_rows,
    should_reconcile_quotes_to_eod,
)

_NY = ZoneInfo("America/New_York")


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


def test_should_reconcile_quotes_to_eod_only_when_market_closed():
    sunday = datetime(2026, 6, 7, 12, 0, tzinfo=_NY)
    monday_open = datetime(2026, 6, 8, 11, 0, tzinfo=_NY)
    monday_premarket = datetime(2026, 6, 8, 8, 0, tzinfo=_NY)

    assert should_reconcile_quotes_to_eod(now=sunday) is True
    assert should_reconcile_quotes_to_eod(now=monday_open) is False
    assert should_reconcile_quotes_to_eod(now=monday_premarket) is False


def test_reconcile_quotes_from_eod_rows_batch():
    quotes = [
        MarketQuote(
            symbol="AAPL",
            name="Apple",
            price=311.23,
            change_percent=0.0,
            category="stocks",
            provider="marketstack",
        ),
    ]
    eod_rows = [
        {"symbol": "AAPL", "date": "2026-06-04", "close": 311.23},
        {"symbol": "AAPL", "date": "2026-06-05", "close": 307.34, "volume": 100},
    ]

    reconciled = reconcile_quotes_from_eod_rows(quotes, eod_rows)

    assert len(reconciled) == 1
    assert reconciled[0].price == 307.34
    assert reconciled[0].previous_close == 311.23
    assert reconciled[0].volume == 100
