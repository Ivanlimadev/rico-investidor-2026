from __future__ import annotations

from datetime import UTC, date, datetime
from zoneinfo import ZoneInfo

_US_EASTERN = ZoneInfo("America/New_York")


def _parse_iso(value: object) -> datetime | None:
    if not value:
        return None
    text = str(value).strip()
    if not text:
        return None
    try:
        if text.endswith("Z"):
            text = text[:-1] + "+00:00"
        return datetime.fromisoformat(text)
    except ValueError:
        return None


def normalize_us_market_day(value: object) -> str | None:
    """Converte timestamps da Marketstack para a data de calendário nos EUA."""
    text = str(value or "").strip()
    if len(text) == 10 and text[4] == "-" and text[7] == "-":
        return text

    parsed = _parse_iso(value)
    if parsed is None:
        return text[:10] if len(text) >= 10 else None

    if parsed.tzinfo is None:
        # Declarações à meia-noite sem TZ mantêm o dia informado.
        if parsed.hour == 0 and parsed.minute == 0 and parsed.second == 0:
            return parsed.date().isoformat()
        parsed = parsed.replace(tzinfo=UTC)

    return parsed.astimezone(_US_EASTERN).date().isoformat()


def investidor10_com_date(ex_date: str | None) -> str | None:
    """Último pregão US (NYSE) antes da data ex — padrão Investidor10 para stocks."""
    if not ex_date or len(ex_date) < 10:
        return None

    from app.domain.market_calendar.trading_calendar import previous_trading_day

    day = date.fromisoformat(ex_date[:10])
    return previous_trading_day(day, market="us").isoformat()
