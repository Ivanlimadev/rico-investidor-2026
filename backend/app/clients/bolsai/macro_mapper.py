from __future__ import annotations

from app.clients.brapi.models import BrazilMacroResponse


def _series_rows(payload: dict) -> list[dict]:
    rows = payload.get("data") or payload.get("series") or payload.get("history") or []
    if isinstance(rows, list):
        return [row for row in rows if isinstance(row, dict)]
    return []


def _daily_rate_to_annual_pct(value: float) -> float:
    """Bolsai BCB: taxa diária em pontos percentuais (ex.: 0.0534 → ~13.5% a.a.)."""
    if value <= 0:
        return value
    if value > 1:
        return round(value, 4)
    return round(value * 252, 2)


def _ipca_12m_from_monthly(rows: list[dict]) -> tuple[float | None, str | None]:
    if not rows:
        return None, None
    latest = rows[0]
    as_of = latest.get("date")
    if len(rows) < 12:
        raw = latest.get("value")
        try:
            return round(float(raw), 2), str(as_of).split("T", 1)[0] if as_of else None
        except (TypeError, ValueError):
            return None, None

    compound = 1.0
    used = 0
    for row in rows[:12]:
        raw = row.get("value")
        if raw is None:
            continue
        try:
            compound *= 1.0 + float(raw) / 100.0
            used += 1
        except (TypeError, ValueError):
            continue
    if used == 0:
        return None, None
    return round((compound - 1.0) * 100.0, 2), str(as_of).split("T", 1)[0] if as_of else None


def _latest_annual_rate(payload: dict) -> tuple[float | None, str | None]:
    rows = _series_rows(payload)
    if not rows:
        return None, None
    row = rows[0]
    raw = row.get("value") or row.get("rate") or row.get("close")
    date = row.get("date") or row.get("as_of")
    try:
        return _daily_rate_to_annual_pct(float(raw)), str(date).split("T", 1)[0] if date else None
    except (TypeError, ValueError):
        return None, None


def merge_bolsai_macro(
    base: BrazilMacroResponse,
    *,
    selic: dict | None = None,
    ipca: dict | None = None,
    cdi: dict | None = None,
) -> BrazilMacroResponse:
    updates: dict[str, object] = {}
    used_bolsai = False

    if selic:
        value, as_of = _latest_annual_rate(selic)
        if value is not None:
            updates["selic"] = value
            if as_of:
                updates["selic_as_of"] = as_of
            used_bolsai = True

    if ipca:
        value, as_of = _ipca_12m_from_monthly(_series_rows(ipca))
        if value is not None:
            updates["ipca_12m"] = value
            if as_of:
                updates["ipca_as_of"] = as_of
            used_bolsai = True

    if cdi:
        value, as_of = _latest_annual_rate(cdi)
        if value is not None:
            updates["cdi"] = value
            if as_of:
                updates["cdi_as_of"] = as_of
            used_bolsai = True

    if not updates:
        return base

    provider = "hybrid" if base.provider == "brapi" and used_bolsai else "bolsai"
    return base.model_copy(update={**updates, "provider": provider})
