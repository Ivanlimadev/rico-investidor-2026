from __future__ import annotations

from app.clients.brapi.models import StockCorporateAction


def map_bolsai_corporate_actions(payload: dict) -> list[StockCorporateAction]:
    rows = payload.get("events") or payload.get("corporate_events") or payload.get("data") or []
    if not isinstance(rows, list):
        return []
    actions: list[StockCorporateAction] = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        label = row.get("type") or row.get("label") or row.get("event_type")
        factor = row.get("factor") or row.get("ratio")
        ex_date = row.get("ex_date") or row.get("date") or row.get("effective_date")
        complete = (
            row.get("complete_factor")
            or row.get("description")
            or (
                f"{row.get('ratio_from')}:{row.get('ratio_to')}"
                if row.get("ratio_from") and row.get("ratio_to")
                else None
            )
        )
        if not label and factor is None:
            continue
        try:
            factor_f = float(factor) if factor is not None else None
        except (TypeError, ValueError):
            factor_f = None
        actions.append(
            StockCorporateAction(
                label=str(label) if label else None,
                factor=factor_f,
                complete_factor=str(complete) if complete else None,
                ex_date=str(ex_date).split("T", 1)[0] if ex_date else None,
            )
        )
    return actions
