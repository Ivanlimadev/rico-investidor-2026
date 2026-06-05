from __future__ import annotations

from datetime import date, timedelta

from app.domain.dividends.calendar_models import DividendCalendarEntry


def _parse_day(raw: str | None) -> date | None:
    if not raw or len(str(raw).strip()) < 10:
        return None
    try:
        return date.fromisoformat(str(raw).strip()[:10])
    except ValueError:
        return None


def _in_window(day: date | None, *, start: date, end: date) -> bool:
    if day is None:
        return False
    return start <= day <= end


def filter_upcoming_entries(
    entries: list[DividendCalendarEntry],
    *,
    days_ahead: int = 120,
    today: date | None = None,
) -> list[DividendCalendarEntry]:
    """Mantém linhas com data com ou pagamento dentro da janela [hoje, hoje+days_ahead]."""
    anchor = today or date.today()
    end = anchor + timedelta(days=max(1, days_ahead))
    filtered: list[DividendCalendarEntry] = []

    for entry in entries:
        pay = _parse_day(entry.payment_date)
        com = _parse_day(entry.com_date)
        pay_upcoming = pay is not None and _in_window(pay, start=anchor, end=end)
        com_upcoming = com is not None and _in_window(com, start=anchor, end=end)
        if pay_upcoming or com_upcoming:
            filtered.append(entry)

    return filtered


def sort_calendar_entries(
    entries: list[DividendCalendarEntry],
    *,
    sort_by: str,
) -> list[DividendCalendarEntry]:
    key_name = (sort_by or "payment").strip().lower()

    def sort_key(item: DividendCalendarEntry) -> tuple[str, str, str]:
        if key_name == "com":
            primary = item.com_date or "9999-99-99"
            secondary = item.payment_date or "9999-99-99"
        else:
            primary = item.payment_date or item.com_date or "9999-99-99"
            secondary = item.com_date or "9999-99-99"
        return (primary, secondary, item.symbol)

    return sorted(entries, key=sort_key)
