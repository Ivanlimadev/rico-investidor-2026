from __future__ import annotations

from datetime import datetime, time
from zoneinfo import ZoneInfo

from app.domain.market_calendar.trading_calendar import US_NYSE_HOLIDAYS, is_us_trading_day

_NY = ZoneInfo("America/New_York")

_STATUS_LABELS = {
    "open": "Pregão aberto",
    "premarket": "Pré-mercado",
    "afterhours": "After hours",
    "closed": "Mercado fechado",
    "holiday": "Feriado NYSE — mercado fechado",
}


def us_market_session(*, now: datetime | None = None) -> dict[str, str | bool]:
    """Estado do pregão NYSE/NASDAQ (horário de Nova York + feriados listados)."""
    local = (now or datetime.now(_NY)).astimezone(_NY)
    calendar_day = local.date()
    is_holiday = calendar_day in US_NYSE_HOLIDAYS

    if is_holiday or not is_us_trading_day(calendar_day):
        return {
            "timezone": "America/New_York",
            "status": "closed",
            "is_open": False,
            "is_holiday": is_holiday,
            "label": _STATUS_LABELS["holiday"] if is_holiday else _STATUS_LABELS["closed"],
            "as_of": local.isoformat(),
        }

    clock = local.time()
    if time(9, 30) <= clock < time(16, 0):
        status = "open"
        is_open = True
    elif time(4, 0) <= clock < time(9, 30):
        status = "premarket"
        is_open = False
    elif time(16, 0) <= clock < time(20, 0):
        status = "afterhours"
        is_open = False
    else:
        status = "closed"
        is_open = False

    return {
        "timezone": "America/New_York",
        "status": status,
        "is_open": is_open,
        "is_holiday": False,
        "label": _STATUS_LABELS[status],
        "as_of": local.isoformat(),
    }


def quote_cache_ttl_seconds(
    *,
    realtime_enabled: bool,
    base_realtime: int,
    base_eod: int,
    now: datetime | None = None,
) -> int:
    """TTL menor com pregão aberto; maior fora do horário ou fim de semana."""
    session = us_market_session(now=now)
    if not realtime_enabled:
        return base_eod
    if session["is_open"]:
        return base_realtime
    if session["status"] in {"premarket", "afterhours"}:
        return max(base_realtime * 2, 120)
    return max(base_eod, 300)
