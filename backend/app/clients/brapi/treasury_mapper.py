from __future__ import annotations

from app.domain.treasury.models import (
    TreasuryBond,
    TreasuryHistoryPoint,
    TreasuryHistoryResponse,
    TreasuryListResponse,
    TreasuryRateInfo,
)


def _to_float(value: object | None) -> float | None:
    if value is None or value == "":
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def normalize_treasury_symbol(raw: str) -> str:
    return raw.strip().lower()


def map_rate_info(raw: object | None) -> TreasuryRateInfo | None:
    if not isinstance(raw, dict):
        return None
    return TreasuryRateInfo(
        rate_type=raw.get("rateType"),
        rate_unit=raw.get("rateUnit"),
        description=raw.get("description"),
    )


def map_treasury_bond(item: dict) -> TreasuryBond:
    symbol = normalize_treasury_symbol(str(item.get("symbol") or ""))
    return TreasuryBond(
        symbol=symbol,
        bond_type=str(item.get("bondType") or symbol),
        indexer=item.get("indexer"),
        coupon_type=item.get("couponType"),
        maturity_date=item.get("maturityDate"),
        duration_days=item.get("durationDays"),
        base_date=item.get("baseDate"),
        buy_rate=_to_float(item.get("buyRate")),
        sell_rate=_to_float(item.get("sellRate")),
        buy_price=_to_float(item.get("buyPrice")),
        sell_price=_to_float(item.get("sellPrice")),
        base_price=_to_float(item.get("basePrice")),
        rate_info=map_rate_info(item.get("rateInfo")),
    )


def map_treasury_list(data: dict, *, group: str = "all") -> TreasuryListResponse:
    items = [map_treasury_bond(item) for item in data.get("results") or [] if isinstance(item, dict)]
    pagination = data.get("pagination") or {}
    page = int(pagination.get("page") or 1)
    total = int(pagination.get("totalItems") or len(items))
    total_pages = int(pagination.get("totalPages") or 1)
    return TreasuryListResponse(
        items=items,
        count=len(items),
        total=total,
        page=page,
        total_pages=total_pages,
        group=group,
    )


def map_treasury_indicators(data: dict) -> list[TreasuryBond]:
    return [map_treasury_bond(item) for item in data.get("results") or [] if isinstance(item, dict)]


def map_treasury_history(data: dict, *, symbol: str, limit: int | None = None) -> TreasuryHistoryResponse:
    normalized = normalize_treasury_symbol(symbol)
    results = data.get("results") or []
    selected = next(
        (
            item
            for item in results
            if isinstance(item, dict) and normalize_treasury_symbol(str(item.get("symbol") or "")) == normalized
        ),
        None,
    )
    if selected is None and results and isinstance(results[0], dict):
        selected = results[0]

    if not selected:
        return TreasuryHistoryResponse(symbol=normalized)

    history = [
        TreasuryHistoryPoint(
            date=str(point.get("baseDate")),
            buy_rate=_to_float(point.get("buyRate")),
            sell_rate=_to_float(point.get("sellRate")),
            buy_price=_to_float(point.get("buyPrice")),
            sell_price=_to_float(point.get("sellPrice")),
            base_price=_to_float(point.get("basePrice")),
        )
        for point in selected.get("history") or []
        if isinstance(point, dict) and point.get("baseDate") is not None
    ]
    history.sort(key=lambda point: point.date)
    if limit and len(history) > limit:
        history = history[-limit:]

    return TreasuryHistoryResponse(
        symbol=normalize_treasury_symbol(str(selected.get("symbol") or normalized)),
        bond_type=selected.get("bondType"),
        indexer=selected.get("indexer"),
        coupon_type=selected.get("couponType"),
        maturity_date=selected.get("maturityDate"),
        rate_info=map_rate_info(selected.get("rateInfo")),
        history=history,
        count=len(history),
    )
