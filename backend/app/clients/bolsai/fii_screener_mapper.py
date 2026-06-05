from __future__ import annotations

from app.clients.brapi.fii_catalog import ScreenerFilters, _matches_filters, sort_screener_items
from app.domain.fii.models import FiiListItem, FiiScreenerItem, FiiScreenerResponse


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


def build_bolsai_fii_screener_params(filters: ScreenerFilters) -> dict[str, str | int | float]:
    fetch_limit = filters.limit + filters.offset
    if filters.search or filters.fund_type:
        fetch_limit = max(fetch_limit, 500)
    params: dict[str, str | int | float] = {
        "limit": min(500, max(fetch_limit, filters.limit)),
        "offset": 0,
        "sort": filters.sort,
        "order": filters.order,
    }
    if filters.dividend_yield_ttm_gt is not None:
        params["dividend_yield_ttm_gt"] = filters.dividend_yield_ttm_gt
    if filters.dividend_yield_ttm_lt is not None:
        params["dividend_yield_ttm_lt"] = filters.dividend_yield_ttm_lt
    if filters.pvp_gt is not None:
        params["pvp_gt"] = filters.pvp_gt
    if filters.pvp_lt is not None:
        params["pvp_lt"] = filters.pvp_lt
    if filters.vacancy_pct_lt is not None:
        params["vacancy_pct_lt"] = filters.vacancy_pct_lt
    if filters.segment:
        params["segment"] = filters.segment
    return params


def map_bolsai_fii_screener_row(row: dict) -> FiiScreenerItem | None:
    if not isinstance(row, dict):
        return None
    ticker = str(row.get("ticker") or "").upper().strip()
    if not ticker:
        return None
    fund_type = row.get("fund_type")
    return FiiScreenerItem(
        ticker=ticker,
        name=str(row.get("name") or ticker),
        segment=row.get("segment"),
        management_type=row.get("management_type"),
        mandate=row.get("mandate"),
        administrator_name=row.get("administrator_name"),
        fund_type=fund_type.title() if isinstance(fund_type, str) and fund_type else None,
        reference_date=row.get("reference_date"),
        close_price=_float(row.get("close_price")),
        book_value_per_share=_float(row.get("book_value_per_share")),
        net_asset_value=_float(row.get("net_asset_value")),
        shares_outstanding=_float(row.get("shares_outstanding")),
        total_shareholders=_int(row.get("total_shareholders")),
        pvp=_float(row.get("pvp")),
        dividend_yield_ttm=_float(row.get("dividend_yield_ttm")),
        dy_month_pct=_float(row.get("dy_month_pct")),
        vacancy_pct=_float(row.get("vacancy_pct")),
        delinquency_pct=_float(row.get("delinquency_pct")),
        leased_pct=_float(row.get("leased_pct")),
        property_count=_int(row.get("property_count")),
        total_area_sqm=_float(row.get("total_area_sqm")),
        provider="bolsai",
    )


def map_bolsai_fii_list_row(row: dict) -> FiiListItem | None:
    if not isinstance(row, dict):
        return None
    ticker = str(row.get("ticker") or "").upper().strip()
    if not ticker:
        return None
    return FiiListItem(
        ticker=ticker,
        name=str(row.get("name") or ticker),
        segment=row.get("segment"),
        management_type=row.get("management_type"),
        total_shareholders=_int(row.get("total_shareholders")),
    )


def map_bolsai_fii_screener(
    payload: dict,
    *,
    filters: ScreenerFilters,
) -> FiiScreenerResponse:
    rows = payload.get("data") or []
    if not isinstance(rows, list):
        rows = []

    items: list[FiiScreenerItem] = []
    for row in rows:
        mapped = map_bolsai_fii_screener_row(row)
        if mapped is not None:
            items.append(mapped)

    if filters.search:
        query = filters.search.lower()
        items = [
            item
            for item in items
            if query in item.ticker.lower() or query in item.name.lower()
        ]

    if filters.fund_type:
        fund = filters.fund_type.lower()
        items = [item for item in items if fund in (item.fund_type or "").lower()]

    filtered = [item for item in items if _matches_filters(item, filters)]
    sorted_items = sort_screener_items(filtered, sort=filters.sort, order=filters.order)
    page = sorted_items[filters.offset : filters.offset + filters.limit]

    total = int(payload.get("total") or len(filtered))
    if filters.search or filters.fund_type:
        total = len(filtered)

    return FiiScreenerResponse(
        data=page,
        count=len(page),
        total=total,
        offset=filters.offset,
        limit=filters.limit,
        provider="hybrid",
    )
