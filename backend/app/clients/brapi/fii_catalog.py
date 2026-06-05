from __future__ import annotations

import time
from dataclasses import dataclass

from app.clients.brapi.fii_mapper import normalize_reference_date, pct_from_ratio
from app.clients.brapi.schema_validation import (
    indicators_by_symbol,
    parse_fii_indicators_response,
    parse_list_stocks,
    parse_quote_list_response,
)
from app.config import settings
from app.core.exceptions import AppError, UpstreamError
from app.domain.fii.models import FiiListItem, FiiListResponse, FiiScreenerItem, FiiScreenerResponse
from app.domain.fii.ticker import is_valid_fii_ticker
from app.domain.quotes.category_map import looks_like_fii

_INDICATORS_BATCH = 20
_ALLOWED_SORT = {
    "dividend_yield_ttm",
    "pvp",
    "vacancy_pct",
    "book_value_per_share",
    "net_asset_value",
    "close_price",
    "ticker",
}
_fund_stocks_cache: tuple[float, list[dict]] | None = None


@dataclass(frozen=True)
class ScreenerFilters:
    limit: int = 50
    offset: int = 0
    sort: str = "dividend_yield_ttm"
    order: str = "desc"
    search: str | None = None
    segment: str | None = None
    fund_type: str | None = None
    dividend_yield_ttm_gt: float | None = None
    dividend_yield_ttm_lt: float | None = None
    pvp_gt: float | None = None
    pvp_lt: float | None = None
    vacancy_pct_lt: float | None = None
    needs_indicators: bool = False


def parse_screener_params(params: dict[str, str]) -> ScreenerFilters:
    def _float(key: str) -> float | None:
        raw = params.get(key)
        if raw is None or raw == "":
            return None
        try:
            return float(raw)
        except ValueError as exc:
            raise AppError(f"Parâmetro inválido: {key}", status_code=400) from exc

    sort = params.get("sort", "dividend_yield_ttm")
    order = params.get("order", "desc")
    if sort not in _ALLOWED_SORT:
        raise AppError(f"sort inválido: {sort}", status_code=400)
    if order not in {"asc", "desc"}:
        raise AppError("order deve ser asc ou desc", status_code=400)

    try:
        limit = int(params.get("limit", 50))
        offset = int(params.get("offset", 0))
    except ValueError as exc:
        raise AppError("limit/offset inválidos", status_code=400) from exc

    if limit < 1 or limit > 500:
        raise AppError("limit deve estar entre 1 e 500", status_code=400)
    if offset < 0:
        raise AppError("offset deve ser >= 0", status_code=400)

    dy_gt = _float("dividend_yield_ttm_gt")
    dy_lt = _float("dividend_yield_ttm_lt")
    pvp_gt = _float("pvp_gt")
    pvp_lt = _float("pvp_lt")
    vacancy_lt = _float("vacancy_pct_lt")
    segment = params.get("segment")
    fund_type = params.get("fund_type")
    search = params.get("search") or params.get("q")

    needs_indicators = any(
        value is not None
        for value in (dy_gt, dy_lt, pvp_gt, pvp_lt, vacancy_lt, segment, fund_type)
    ) or sort in {"dividend_yield_ttm", "pvp", "vacancy_pct", "book_value_per_share", "net_asset_value"}

    return ScreenerFilters(
        limit=limit,
        offset=offset,
        sort=sort,
        order=order,
        search=search.strip() if search else None,
        segment=segment,
        fund_type=fund_type,
        dividend_yield_ttm_gt=dy_gt,
        dividend_yield_ttm_lt=dy_lt,
        pvp_gt=pvp_gt,
        pvp_lt=pvp_lt,
        vacancy_pct_lt=vacancy_lt,
        needs_indicators=needs_indicators,
    )


def map_list_item(stock: dict, indicators: dict | None = None) -> FiiListItem:
    ticker = str(stock.get("stock") or "").upper()
    name = indicators.get("name") if indicators else None
    if not name or name == ticker:
        name = stock.get("name") or ticker
    return FiiListItem(
        ticker=ticker,
        name=name,
        segment=(indicators or {}).get("segmentoAtuacao") or stock.get("sector"),
        management_type=(indicators or {}).get("tipoGestao"),
        total_shareholders=(indicators or {}).get("totalInvestors"),
    )


def map_screener_item(stock: dict, indicators: dict) -> FiiScreenerItem:
    ticker = str(stock.get("stock") or indicators.get("symbol") or "").upper()
    dy = indicators.get("dividendYield12m")
    fund_type = indicators.get("segmentType")
    return FiiScreenerItem(
        ticker=ticker,
        name=indicators.get("name") or stock.get("name") or ticker,
        segment=indicators.get("segmentoAtuacao") or stock.get("sector"),
        management_type=indicators.get("tipoGestao"),
        mandate=indicators.get("mandate"),
        administrator_name=indicators.get("administratorName"),
        fund_type=fund_type.title() if isinstance(fund_type, str) and fund_type else None,
        reference_date=normalize_reference_date(indicators.get("asOfDate")),
        close_price=indicators.get("price") or stock.get("close"),
        book_value_per_share=indicators.get("navPerShare"),
        net_asset_value=indicators.get("equity"),
        shares_outstanding=indicators.get("sharesOutstanding"),
        total_shareholders=indicators.get("totalInvestors"),
        pvp=indicators.get("priceToNav"),
        dividend_yield_ttm=pct_from_ratio(dy) if dy is not None else None,
        provider="brapi",
    )


def _matches_filters(item: FiiScreenerItem, filters: ScreenerFilters) -> bool:
    if filters.search:
        q = filters.search.lower()
        haystack = f"{item.ticker} {item.name}".lower()
        if q not in haystack:
            return False

    if filters.segment:
        segment = (item.segment or "").lower()
        if filters.segment.lower() not in segment:
            return False

    if filters.fund_type:
        fund = (item.fund_type or "").lower()
        if filters.fund_type.lower() not in fund:
            return False

    if filters.dividend_yield_ttm_gt is not None:
        if item.dividend_yield_ttm is None or item.dividend_yield_ttm < filters.dividend_yield_ttm_gt:
            return False

    if filters.dividend_yield_ttm_lt is not None:
        if item.dividend_yield_ttm is None or item.dividend_yield_ttm > filters.dividend_yield_ttm_lt:
            return False

    if filters.pvp_gt is not None:
        if item.pvp is None or item.pvp < filters.pvp_gt:
            return False

    if filters.pvp_lt is not None:
        if item.pvp is None or item.pvp > filters.pvp_lt:
            return False

    return True


def _sort_key(item: FiiScreenerItem, sort: str):
    mapping = {
        "dividend_yield_ttm": item.dividend_yield_ttm,
        "pvp": item.pvp,
        "vacancy_pct": item.vacancy_pct,
        "book_value_per_share": item.book_value_per_share,
        "net_asset_value": item.net_asset_value,
        "close_price": item.close_price,
        "ticker": item.ticker,
    }
    return mapping.get(sort, item.dividend_yield_ttm)


def sort_screener_items(items: list[FiiScreenerItem], *, sort: str, order: str) -> list[FiiScreenerItem]:
    reverse = order.lower() != "asc"

    def key(item: FiiScreenerItem):
        value = _sort_key(item, sort)
        if value is None:
            return (1, 0)
        if isinstance(value, str):
            return (0, value)
        return (0, value)

    return sorted(items, key=key, reverse=reverse)


def _is_fii_listing(stock: dict) -> bool:
    symbol = str(stock.get("stock") or "").upper().strip()
    return is_valid_fii_ticker(symbol) and looks_like_fii(symbol)


async def fetch_fund_stocks(client, *, search: str | None = None, sector: str | None = None) -> list[dict]:
    items: list[dict] = []
    page = 1
    total_count = 0

    while True:
        params: dict[str, str | int] = {
            "limit": 100,
            "page": page,
            "type": "fund",
            "sortBy": "volume",
            "sortOrder": "desc",
        }
        if search:
            params["search"] = search
        if sector:
            params["sector"] = sector

        data = await client._get("/quote/list", params=params)
        envelope = parse_quote_list_response(data)
        stocks = [item for item in parse_list_stocks(data) if _is_fii_listing(item)]
        total_count = int(envelope.totalCount or total_count or len(stocks))
        items.extend(stocks)

        if search or not envelope.hasNextPage or not stocks:
            break
        page += 1

    return items


async def get_cached_fund_stocks(client, *, search: str | None = None, sector: str | None = None) -> list[dict]:
    global _fund_stocks_cache

    if search or sector:
        return await fetch_fund_stocks(client, search=search, sector=sector)

    now = time.monotonic()
    if _fund_stocks_cache is not None and now < _fund_stocks_cache[0]:
        return _fund_stocks_cache[1]

    stocks = await fetch_fund_stocks(client)
    _fund_stocks_cache = (now + settings.fii_fund_catalog_ttl_seconds, stocks)
    return stocks


async def load_lightweight_catalog(client) -> list[FiiListItem]:
    stocks = await get_cached_fund_stocks(client)
    return [
        map_list_item(stock)
        for stock in stocks
        if stock.get("stock")
    ]


async def fetch_indicators_map(client, tickers: list[str]) -> dict[str, dict]:
    if not tickers:
        return {}

    result: dict[str, dict] = {}
    for offset in range(0, len(tickers), _INDICATORS_BATCH):
        batch = tickers[offset : offset + _INDICATORS_BATCH]
        try:
            data = await client._get_v2(
                "v2/fii/indicators",
                params={"symbols": ",".join(batch)},
            )
            result.update(indicators_by_symbol(parse_fii_indicators_response(data)))
        except UpstreamError:
            # Lote com ticker inválido — tenta símbolo a símbolo.
            for symbol in batch:
                try:
                    data = await client._get_v2(
                        "v2/fii/indicators",
                        params={"symbols": symbol},
                    )
                    result.update(indicators_by_symbol(parse_fii_indicators_response(data)))
                except UpstreamError:
                    continue

    return result


async def list_fiis(client, *, limit: int = 500, offset: int = 0) -> FiiListResponse:
    stocks = await get_cached_fund_stocks(client)
    total = len(stocks)
    page_stocks = stocks[offset : offset + limit]

    tickers = [str(item["stock"]).upper() for item in page_stocks if item.get("stock")]
    indicators = await fetch_indicators_map(client, tickers)
    fiis = [map_list_item(stock, indicators.get(str(stock["stock"]).upper())) for stock in page_stocks]
    return FiiListResponse(count=len(fiis), total=total, fiis=fiis, provider="brapi")


async def featured_fiis(client, tickers: tuple[str, ...]) -> FiiScreenerResponse:
    normalized = [ticker.upper() for ticker in tickers if ticker.strip()]
    if not normalized:
        return FiiScreenerResponse(
            data=[],
            count=0,
            total=0,
            offset=0,
            limit=0,
            provider="brapi",
        )

    indicators = await fetch_indicators_map(client, normalized)
    items = [
        map_screener_item({"stock": ticker}, indicators[ticker])
        for ticker in normalized
        if ticker in indicators
    ]
    return FiiScreenerResponse(
        data=items,
        count=len(items),
        total=len(items),
        offset=0,
        limit=len(items),
        provider="brapi",
    )


async def screen_fiis(client, params: dict[str, str]) -> FiiScreenerResponse:
    filters = parse_screener_params(params)
    stocks = await get_cached_fund_stocks(client, search=filters.search, sector=filters.segment)

    if not filters.needs_indicators:
        items = [
            FiiScreenerItem(
                ticker=str(stock["stock"]).upper(),
                name=stock.get("name") or str(stock["stock"]).upper(),
                segment=stock.get("sector"),
                close_price=stock.get("close"),
                provider="brapi",
            )
            for stock in stocks
            if stock.get("stock")
        ]
        filtered = [item for item in items if _matches_filters(item, filters)]
        sorted_items = sort_screener_items(filtered, sort=filters.sort, order=filters.order)
        page = sorted_items[filters.offset : filters.offset + filters.limit]
        return FiiScreenerResponse(
            data=page,
            count=len(page),
            total=len(sorted_items),
            offset=filters.offset,
            limit=filters.limit,
            provider="brapi",
        )

    tickers = [str(stock["stock"]).upper() for stock in stocks if stock.get("stock")]
    indicators = await fetch_indicators_map(client, tickers)
    items = [
        map_screener_item(stock, indicators[str(stock["stock"]).upper()])
        for stock in stocks
        if stock.get("stock") and str(stock["stock"]).upper() in indicators
    ]

    filtered = [item for item in items if _matches_filters(item, filters)]
    sorted_items = sort_screener_items(filtered, sort=filters.sort, order=filters.order)
    page = sorted_items[filters.offset : filters.offset + filters.limit]

    return FiiScreenerResponse(
        data=page,
        count=len(page),
        total=len(sorted_items),
        offset=filters.offset,
        limit=filters.limit,
        provider="brapi",
    )
