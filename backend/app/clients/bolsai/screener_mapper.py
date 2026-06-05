from __future__ import annotations

import math

from app.clients.brapi.models import StockScreenerItem, StockScreenerResponse
from app.domain.quotes.category_map import category_to_slug, infer_category


_SORT_MAP = {
    "dividend_yield": "dy",
    "price_earnings": "pl",
    "return_on_equity": "roe",
    "price_to_book": "pvp",
    "market_cap": "market_cap",
}


def _float(value: object) -> float | None:
    if value is None:
        return None
    try:
        return round(float(value), 4)
    except (TypeError, ValueError):
        return None


def build_bolsai_screener_params(
    *,
    sort_by: str,
    sort_order: str,
    limit: int,
    page: int,
    min_dividend_yield: float | None = None,
    max_dividend_yield: float | None = None,
    min_price_earnings: float | None = None,
    max_price_earnings: float | None = None,
    min_return_on_equity: float | None = None,
    max_return_on_equity: float | None = None,
    min_price_to_book: float | None = None,
    max_price_to_book: float | None = None,
    search: str | None = None,
) -> dict[str, str | int | float]:
    params: dict[str, str | int | float] = {
        "limit": max(1, limit),
        "offset": max(0, (page - 1) * limit),
        "order": sort_order if sort_order in {"asc", "desc"} else "desc",
    }
    bolsai_sort = _SORT_MAP.get(sort_by.strip().lower())
    if bolsai_sort:
        params["sort"] = bolsai_sort

    if min_dividend_yield is not None:
        params["dy_gt"] = min_dividend_yield
    if max_dividend_yield is not None:
        params["dy_lt"] = max_dividend_yield
    if min_price_earnings is not None:
        params["pl_gt"] = min_price_earnings
    if max_price_earnings is not None:
        params["pl_lt"] = max_price_earnings
    if min_return_on_equity is not None:
        params["roe_gt"] = min_return_on_equity
    if max_return_on_equity is not None:
        params["roe_lt"] = max_return_on_equity
    if min_price_to_book is not None:
        params["pvp_gt"] = min_price_to_book
    if max_price_to_book is not None:
        params["pvp_lt"] = max_price_to_book

    if search and search.strip():
        params["search"] = search.strip()

    return params


def map_bolsai_screener(
    payload: dict,
    *,
    page: int = 1,
    limit: int = 50,
    search: str | None = None,
) -> StockScreenerResponse:
    rows = payload.get("data") or []
    if not isinstance(rows, list):
        rows = []

    query = (search or "").strip().lower()
    items: list[StockScreenerItem] = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        symbol = str(row.get("ticker") or "").upper().strip()
        if not symbol:
            continue
        name = str(row.get("corporate_name") or symbol)
        if query and query not in symbol.lower() and query not in name.lower():
            continue
        price = _float(row.get("close_price")) or 0.0
        items.append(
            StockScreenerItem(
                symbol=symbol,
                name=name,
                price=price,
                change_percent=0.0,
                category=category_to_slug(infer_category(symbol, "stock")),
                sector=row.get("sector"),
                market_cap=_float(row.get("market_cap")),
                volume=None,
                dividend_yield_12m=_float(row.get("dividend_yield")),
                price_earnings=_float(row.get("pl")),
                return_on_equity=_float(row.get("roe")),
                price_to_book=_float(row.get("pvp")),
                provider="bolsai",
            )
        )

    total = int(payload.get("total") or len(items))
    total_pages = max(1, math.ceil(total / max(1, limit))) if total else 1
    sectors = sorted({item.sector for item in items if item.sector})

    return StockScreenerResponse(
        items=items,
        count=len(items),
        total=total,
        page=page,
        total_pages=total_pages,
        sectors=sectors,
        provider="hybrid",
    )
