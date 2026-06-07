from datetime import datetime
from unittest.mock import patch
from zoneinfo import ZoneInfo

from app.domain.global_markets.us_market_session import quote_cache_ttl_seconds, us_market_session
from app.services.global_market_service import GlobalMarketService

_NY = ZoneInfo("America/New_York")


def test_us_market_open_on_weekday_session():
    session = us_market_session(now=datetime(2026, 6, 8, 11, 0, tzinfo=_NY))
    assert session["status"] == "open"
    assert session["is_open"] is True
    assert session["label"] == "Pregão aberto"


def test_us_market_closed_on_sunday():
    session = us_market_session(now=datetime(2026, 6, 7, 12, 0, tzinfo=_NY))
    assert session["status"] == "closed"
    assert session["is_open"] is False
    assert session["is_holiday"] is False


def test_us_market_closed_on_nyse_holiday_even_during_regular_hours():
    # Thanksgiving 2026 — quinta 26/11; sem pregão mesmo às 11h NY.
    session = us_market_session(now=datetime(2026, 11, 26, 11, 0, tzinfo=_NY))
    assert session["status"] == "closed"
    assert session["is_open"] is False
    assert session["is_holiday"] is True
    assert session["label"] == "Feriado NYSE — mercado fechado"


def test_us_market_closed_on_observed_independence_day():
    # 4/jul/2026 cai no sábado; NYSE observa sexta 3/jul/2026.
    session = us_market_session(now=datetime(2026, 7, 3, 11, 0, tzinfo=_NY))
    assert session["is_holiday"] is True
    assert session["is_open"] is False


def test_quote_cache_ttl_longer_when_market_closed():
    open_ttl = quote_cache_ttl_seconds(
        realtime_enabled=True,
        base_realtime=60,
        base_eod=300,
        now=datetime(2026, 6, 8, 11, 0, tzinfo=_NY),
    )
    closed_ttl = quote_cache_ttl_seconds(
        realtime_enabled=True,
        base_realtime=60,
        base_eod=300,
        now=datetime(2026, 6, 7, 12, 0, tzinfo=_NY),
    )
    assert open_ttl == 60
    assert closed_ttl >= 300


@patch("app.domain.global_markets.quote_reconcile.us_market_session")
def test_live_intraday_disabled_when_market_closed(mock_session):
    mock_session.return_value = {"is_open": False, "status": "closed"}
    assert GlobalMarketService._live_intraday_enabled() is False


@patch("app.domain.global_markets.quote_reconcile.us_market_session")
def test_live_intraday_enabled_during_regular_hours(mock_session):
    mock_session.return_value = {"is_open": True, "status": "open"}
    assert GlobalMarketService._live_intraday_enabled() is True
