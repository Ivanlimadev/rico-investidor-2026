from __future__ import annotations

from datetime import date, timedelta


def investidor10_br_com_date(ex_date: str | None) -> str | None:
    """Data com exibida no Investidor10 para B3: dia útil anterior ao ex-date.

    Ex.: ex 2026-06-02 (terça) → com 2026-06-01 (segunda). Não considera feriados B3.
    """
    if not ex_date or len(ex_date) < 10:
        return None
    try:
        day = date.fromisoformat(ex_date[:10])
    except ValueError:
        return None
    candidate = day - timedelta(days=1)
    while candidate.weekday() >= 5:
        candidate -= timedelta(days=1)
    return candidate.isoformat()
