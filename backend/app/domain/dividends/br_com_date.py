from __future__ import annotations

from datetime import date

from app.domain.market_calendar.trading_calendar import previous_trading_day


def investidor10_br_com_date(ex_date: str | None) -> str | None:
    """Data com exibida no Investidor10 para B3: último pregão antes do ex-date."""
    if not ex_date or len(ex_date) < 10:
        return None
    try:
        day = date.fromisoformat(ex_date[:10])
    except ValueError:
        return None
    return previous_trading_day(day, market="br").isoformat()
