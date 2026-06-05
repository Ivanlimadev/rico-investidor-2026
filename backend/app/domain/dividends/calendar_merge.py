from __future__ import annotations

from app.domain.dividends.calendar_models import DividendCalendarEntry


def _entry_key(entry: DividendCalendarEntry) -> tuple[str, str, str, str]:
    return (
        entry.symbol.upper(),
        entry.com_date[:10],
        (entry.payment_date or "")[:10],
        entry.dividend_type.strip().lower(),
    )


def merge_br_dividend_entries(
    *,
    bolsai: list[DividendCalendarEntry],
    brapi: list[DividendCalendarEntry],
) -> list[DividendCalendarEntry]:
    """Bolsai primeiro; linhas extras da Brapi entram se não duplicarem a chave."""
    seen: set[tuple[str, str, str, str]] = set()
    merged: list[DividendCalendarEntry] = []

    for entry in bolsai:
        key = _entry_key(entry)
        if key in seen:
            continue
        seen.add(key)
        merged.append(entry)

    for entry in brapi:
        key = _entry_key(entry)
        if key in seen:
            continue
        seen.add(key)
        merged.append(entry)

    return merged
