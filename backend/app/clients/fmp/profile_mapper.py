from __future__ import annotations

from app.domain.global_markets.models import GlobalStockCompanyProfile


def _clean_str(value: object) -> str | None:
    if isinstance(value, str) and value.strip():
        return value.strip()
    return None


def _safe_int(value: object) -> int | None:
    if value is None:
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _safe_float(value: object) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def fmp_company_updates(profile: GlobalStockCompanyProfile, fmp: dict | None) -> GlobalStockCompanyProfile:
    """Preenche apenas os campos do perfil que estão vazios — não sobrescreve a
    Marketstack quando ela já trouxe a informação."""
    if not fmp:
        return profile

    updates: dict = {}

    sector = _clean_str(fmp.get("sector"))
    if sector and not profile.sector:
        updates["sector"] = sector

    industry = _clean_str(fmp.get("industry"))
    if industry and not profile.industry:
        updates["industry"] = industry

    summary = _clean_str(fmp.get("description"))
    if summary and not profile.summary:
        updates["summary"] = summary

    website = _clean_str(fmp.get("website"))
    if website and not profile.website:
        updates["website"] = website

    country = _clean_str(fmp.get("country"))
    if country and not profile.country:
        updates["country"] = country

    employees = _safe_int(fmp.get("fullTimeEmployees"))
    if employees is not None and profile.employees is None:
        updates["employees"] = employees

    return profile.model_copy(update=updates) if updates else profile


def fmp_market_cap(fmp: dict | None) -> float | None:
    if not fmp:
        return None
    return _safe_float(fmp.get("marketCap") or fmp.get("mktCap"))
