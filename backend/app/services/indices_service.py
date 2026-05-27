from app.clients.brapi.client import BrapiClient
from app.clients.brapi.index_mapper import map_index_history, map_index_quote, normalize_index_symbol
from app.config import settings
from app.core.cache import TtlCache
from app.core.exceptions import UpstreamError
from app.domain.indices.models import (
    IndexDetailResponse,
    IndexExploreResponse,
    IndexHistoryResponse,
    IndexListResponse,
    IndexQuote,
)
from app.domain.indices.presets import (
    FEATURED_INDEX_SYMBOLS,
    INDEX_CATALOG,
    INDEX_BY_SYMBOL,
    INDEX_EXPLORE_GROUPS,
    IndexPreset,
)


class IndicesService:
    def __init__(self, client: BrapiClient | None = None) -> None:
        self._client = client or BrapiClient()
        ttl = settings.quote_cache_ttl_seconds
        self._featured_cache: TtlCache[IndexListResponse] = TtlCache(ttl)
        self._quote_cache: TtlCache[IndexQuote] = TtlCache(ttl)
        self._detail_cache: TtlCache[IndexDetailResponse] = TtlCache(ttl * 2)
        self._history_cache: TtlCache[IndexHistoryResponse] = TtlCache(ttl * 2)

    def _filter_catalog(
        self,
        *,
        search: str | None = None,
        group: str = "all",
    ) -> list[IndexPreset]:
        normalized_group = group.strip().lower() or "all"
        group_key = INDEX_EXPLORE_GROUPS.get(normalized_group)
        items = list(INDEX_CATALOG)

        if group_key:
            items = [item for item in items if item.group == group_key]

        if search:
            query = search.strip().lower()
            items = [
                item
                for item in items
                if query in item.symbol.lower()
                or query in item.name.lower()
                or query in normalize_index_symbol(item.symbol).lower()
            ]

        return items

    async def _fetch_quotes(self, presets: list[IndexPreset]) -> list[IndexQuote]:
        if not presets:
            return []

        symbols = [item.symbol for item in presets]
        raw_items = await self._client.get_quotes_raw(symbols)
        by_symbol = {normalize_index_symbol(str(item.get("symbol") or "")): item for item in raw_items}

        quotes: list[IndexQuote] = []
        for preset in presets:
            raw = by_symbol.get(normalize_index_symbol(preset.symbol))
            if raw is None:
                continue
            quote = map_index_quote(raw, preset=preset)
            quotes.append(quote)
            self._quote_cache.set(quote.symbol, quote)
        return quotes

    async def list_featured(self) -> IndexListResponse:
        cached = self._featured_cache.get("featured")
        if cached:
            return cached

        presets = [INDEX_BY_SYMBOL[symbol] for symbol in FEATURED_INDEX_SYMBOLS if symbol in INDEX_BY_SYMBOL]
        items = await self._fetch_quotes(presets)
        result = IndexListResponse(items=items, count=len(items))
        self._featured_cache.set("featured", result)
        return result

    async def explore(
        self,
        *,
        search: str | None = None,
        group: str = "all",
        page: int = 1,
        limit: int = 30,
    ) -> IndexExploreResponse:
        normalized_group = group.strip().lower() or "all"
        safe_limit = max(1, min(limit, 50))
        safe_page = max(1, page)

        catalog = self._filter_catalog(search=search, group=normalized_group)
        total = len(catalog)
        total_pages = max(1, (total + safe_limit - 1) // safe_limit)
        safe_page = min(safe_page, total_pages)
        start = (safe_page - 1) * safe_limit
        page_items = catalog[start : start + safe_limit]
        items = await self._fetch_quotes(page_items)

        return IndexExploreResponse(
            items=items,
            count=len(items),
            total=total,
            page=safe_page,
            total_pages=total_pages,
            group=normalized_group,
        )

    async def count_indices(self) -> int:
        return len(INDEX_CATALOG)

    async def get_quote(self, symbol: str) -> IndexQuote:
        normalized = normalize_index_symbol(symbol)
        cached = self._quote_cache.get(normalized)
        if cached:
            return cached

        preset = INDEX_BY_SYMBOL.get(normalized)
        raw = await self._client.get_quote_item(normalized)
        quote = map_index_quote(raw, preset=preset)
        self._quote_cache.set(normalized, quote)
        return quote

    async def get_history(self, symbol: str, *, limit: int = 252) -> IndexHistoryResponse:
        normalized = normalize_index_symbol(symbol)
        cache_key = f"history:{normalized}:{limit}"
        cached = self._history_cache.get(cache_key)
        if cached:
            return cached

        candles = await self._client.get_stock_candles(normalized, limit=limit)
        history = map_index_history(candles.candles, symbol=normalized)
        result = IndexHistoryResponse(symbol=normalized, history=history, count=len(history))
        self._history_cache.set(cache_key, result)
        return result

    async def get_detail(self, symbol: str, *, history_limit: int = 252) -> IndexDetailResponse:
        normalized = normalize_index_symbol(symbol)
        cache_key = f"detail:{normalized}:{history_limit}"
        cached = self._detail_cache.get(cache_key)
        if cached:
            return cached

        if normalized not in INDEX_BY_SYMBOL:
            raise UpstreamError("Índice não encontrado", status_code=404)

        quote = await self.get_quote(normalized)
        history_response = await self.get_history(normalized, limit=history_limit)
        result = IndexDetailResponse(quote=quote, history=history_response.history)
        self._detail_cache.set(cache_key, result)
        return result


indices_service = IndicesService()
