from __future__ import annotations

from app.clients.brapi.models import BrazilMacroResponse, DictionaryField, DictionaryResponse


def map_brazil_macro(*, prime_rate_data: dict, inflation_data: dict) -> BrazilMacroResponse:
    selic_rows = prime_rate_data.get("prime-rate") or []
    ipca_rows = inflation_data.get("inflation") or []
    selic = selic_rows[0] if selic_rows else None
    ipca = ipca_rows[0] if ipca_rows else None

    return BrazilMacroResponse(
        selic=float(selic["value"]) if selic and selic.get("value") is not None else None,
        selic_as_of=selic.get("date") if selic else None,
        ipca_12m=float(ipca["value"]) if ipca and ipca.get("value") is not None else None,
        ipca_as_of=ipca.get("date") if ipca else None,
    )


def map_dictionary(data: dict, *, category: str) -> DictionaryResponse:
    fields = [
        DictionaryField(
            key=str(item.get("key") or ""),
            label=item.get("label"),
            description=item.get("description"),
            calculation=item.get("calculation"),
            category=item.get("category") or category,
        )
        for item in data.get("fields") or []
        if item.get("key")
    ]
    return DictionaryResponse(category=category, fields=fields, count=len(fields))
