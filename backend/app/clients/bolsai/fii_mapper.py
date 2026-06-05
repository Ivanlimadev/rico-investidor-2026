from __future__ import annotations

from app.domain.fii.models import FiiAssetComposition, FiiDetail, FiiFeesPaid, FiiProperty


def _float(value: object) -> float | None:
    if value is None:
        return None
    try:
        return round(float(value), 4)
    except (TypeError, ValueError):
        return None


def _int(value: object) -> int | None:
    if value is None:
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _map_asset_composition(raw: dict) -> FiiAssetComposition | None:
    comp = FiiAssetComposition(
        real_estate_leased_pct=_float(
            raw.get("real_estate_leased_pct") or raw.get("real_estate_pct") or raw.get("imoveis_pct")
        ),
        real_estate_under_construction_pct=_float(raw.get("real_estate_under_construction_pct")),
        real_estate_for_sale_pct=_float(raw.get("real_estate_for_sale_pct")),
        land_pct=_float(raw.get("land_pct")),
        other_real_estate_pct=_float(raw.get("other_real_estate_pct")),
        cri_pct=_float(raw.get("cri_pct")),
        lci_pct=_float(raw.get("lci_pct")),
        cepac_pct=_float(raw.get("cepac_pct")),
        debentures_pct=_float(raw.get("debentures_pct")),
        fii_holdings_pct=_float(raw.get("fii_holdings_pct")),
        fip_fdic_pct=_float(raw.get("fip_fdic_pct")),
        stocks_pct=_float(raw.get("stocks_pct")),
        cash_pct=_float(raw.get("cash_pct")),
        other_pct=_float(raw.get("other_pct")),
    )
    if any(getattr(comp, field) is not None for field in FiiAssetComposition.model_fields):
        return comp
    return None


def _map_properties(rows: list) -> list[FiiProperty]:
    mapped: list[FiiProperty] = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        name = row.get("name") or row.get("property_name")
        if not name:
            continue
        mapped.append(
            FiiProperty(
                name=str(name),
                address=row.get("address"),
                asset_class=row.get("asset_class"),
                area_sqm=_float(row.get("area_sqm") or row.get("area")),
                revenue_pct=_float(row.get("revenue_pct")),
                vacancy_pct=_float(row.get("vacancy_pct")),
                leased_pct=_float(row.get("leased_pct")),
            )
        )
    return mapped


def map_fii_detail_from_bolsai(payload: dict) -> FiiDetail | None:
    """Monta FiiDetail completo a partir de GET /fiis/{ticker}."""
    ticker = str(payload.get("ticker") or "").upper().strip()
    if not ticker:
        return None

    composition_raw = payload.get("asset_composition") or payload.get("composition")
    composition = (
        _map_asset_composition(composition_raw) if isinstance(composition_raw, dict) else None
    )

    fees_raw = payload.get("fees_paid_last_month")
    fees = None
    if isinstance(fees_raw, dict):
        fees = FiiFeesPaid(
            admin=_float(fees_raw.get("admin")),
            performance=_float(fees_raw.get("performance")),
        )

    properties = _map_properties(payload.get("top_properties") or payload.get("properties") or [])

    return FiiDetail(
        ticker=ticker,
        name=str(payload.get("name") or ticker),
        reference_date=str(payload.get("reference_date") or "") or None,
        close_price=_float(payload.get("close_price") or payload.get("price")),
        book_value_per_share=_float(payload.get("book_value_per_share")),
        pvp=_float(payload.get("pvp")),
        dividend_yield_ttm=_float(payload.get("dividend_yield_ttm") or payload.get("dividend_yield")),
        net_asset_value=_float(payload.get("net_asset_value")),
        shares_outstanding=_float(payload.get("shares_outstanding")),
        total_shareholders=_int(payload.get("total_shareholders")),
        segment=payload.get("segment"),
        management_type=payload.get("management_type"),
        administrator=payload.get("administrator"),
        administrator_cnpj=payload.get("administrator_cnpj"),
        mandate=payload.get("mandate"),
        inception_date=payload.get("inception_date"),
        duration_type=payload.get("duration_type"),
        target_investors=payload.get("target_investors"),
        website=payload.get("website"),
        email=payload.get("email"),
        fund_type=payload.get("fund_type"),
        asset_composition=composition,
        fees_paid_last_month=fees,
        property_count=_int(payload.get("property_count")),
        total_area_sqm=_float(payload.get("total_area_sqm")),
        vacancy_pct=_float(payload.get("vacancy_pct")),
        delinquency_pct=_float(payload.get("delinquency_pct")),
        leased_pct=_float(payload.get("leased_pct")),
        top_properties=properties,
        property_reference_date=payload.get("property_reference_date"),
        provider="bolsai",
    )


def merge_bolsai_fii_detail(detail: FiiDetail, payload: dict) -> FiiDetail:
    """Sobrepõe métricas da Bolsai sobre detalhe Brapi (fallback parcial)."""
    mapped = map_fii_detail_from_bolsai(payload)
    if mapped is None:
        return detail

    updates = mapped.model_dump(exclude_none=True)
    updates.pop("ticker", None)
    if not updates:
        return detail
    return detail.model_copy(update=updates)
