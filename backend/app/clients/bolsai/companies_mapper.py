from __future__ import annotations

from app.clients.brapi.models import StockProfile


def company_display_name(payload: dict | None) -> str | None:
    if not payload:
        return None
    for key in ("trade_name", "corporate_name"):
        raw = payload.get(key)
        if raw and str(raw).strip():
            cleaned = str(raw).strip()
            if cleaned.upper() not in {"", "N/A"}:
                return cleaned
    return None


def merge_company_into_profile(profile: StockProfile, company: dict) -> StockProfile:
    updates: dict[str, object] = {}
    sector = company.get("sector")
    if sector and not profile.sector:
        updates["sector"] = str(sector).strip()
    website = company.get("website")
    if website and not profile.website:
        updates["website"] = str(website).strip()
    country = company.get("country")
    if country and not profile.country:
        updates["country"] = str(country).strip()
    if updates:
        updates["provider"] = "hybrid"
        return profile.model_copy(update=updates)
    return profile
