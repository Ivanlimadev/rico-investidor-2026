from app.clients.brapi.models import MarketQuote
from app.domain.global_markets.quote_reconcile import (
    apply_fmp_live_quote,
    quote_looks_stale_during_session,
)
from datetime import datetime
from zoneinfo import ZoneInfo

_NY = ZoneInfo("America/New_York")


def test_stale_quote_when_low_below_displayed_price_during_open_session():
    quote = MarketQuote(
        symbol="AAPL",
        name="Apple",
        price=301.54,
        change_percent=-1.89,
        category="stocks",
        provider="marketstack",
        previous_close=307.34,
        low=287.79,
    )
    now = datetime(2026, 6, 9, 15, 0, tzinfo=_NY)
    assert quote_looks_stale_during_session(quote, now=now) is True


def test_apply_fmp_live_quote_updates_price():
    quote = MarketQuote(
        symbol="AAPL",
        name="Apple",
        price=301.54,
        change_percent=-1.89,
        category="stocks",
        provider="marketstack",
        previous_close=307.34,
        low=287.79,
    )
    refreshed = apply_fmp_live_quote(
        quote,
        {
            "symbol": "AAPL",
            "price": 290.22,
            "previousClose": 301.54,
            "changesPercentage": -3.75,
            "dayLow": 287.79,
            "dayHigh": 300.75,
        },
    )
    assert refreshed.price == 290.22
    assert refreshed.previous_close == 301.54
    assert refreshed.change_percent == -3.75
