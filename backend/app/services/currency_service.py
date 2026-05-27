from app.clients.brapi.client import BrapiClient
from app.clients.brapi.currency_mapper import normalize_currency_pair
from app.config import settings
from app.core.cache import TtlCache
from app.domain.currency.models import (
    CurrencyExploreResponse,
    CurrencyHistoryResponse,
    CurrencyListResponse,
    CurrencyPairListResponse,
    CurrencyQuote,
)
from app.domain.currency.presets import CURRENCY_EXPLORE_GROUPS, FEATURED_CURRENCY_PAIRS


class CurrencyService:
    def __init__(self, client: BrapiClient | None = None) -> None:
        self._client = client or BrapiClient()
        ttl = settings.quote_cache_ttl_seconds
        self._rates_cache: TtlCache[CurrencyListResponse] = TtlCache(ttl)
        self._pairs_cache: TtlCache[CurrencyPairListResponse] = TtlCache(ttl * 4)
        self._history_cache: TtlCache[CurrencyHistoryResponse] = TtlCache(ttl * 2)

    async def list_featured(self) -> CurrencyListResponse:
        cache_key = "featured"
        cached = self._rates_cache.get(cache_key)
        if cached:
            return cached

        result = await self._client.get_currency_rates(list(FEATURED_CURRENCY_PAIRS))
        self._rates_cache.set(cache_key, result)
        return result

    async def list_pairs(self, *, search: str | None = None, brl_only: bool = True) -> CurrencyPairListResponse:
        cache_key = f"pairs:{search or ''}:{brl_only}"
        cached = self._pairs_cache.get(cache_key)
        if cached:
            return cached

        result = await self._client.get_currency_available(search=search)
        if brl_only:
            pairs = [pair for pair in result.pairs if pair.pair.endswith("-BRL")]
            result = CurrencyPairListResponse(pairs=pairs, count=len(pairs))
        self._pairs_cache.set(cache_key, result)
        return result

    async def count_brl_pairs(self) -> int:
        pairs = await self.list_pairs()
        return pairs.count

    async def explore(
        self,
        *,
        search: str | None = None,
        group: str = "all",
        page: int = 1,
        limit: int = 30,
    ) -> CurrencyExploreResponse:
        normalized_group = group.strip().lower() or "all"
        group_codes = CURRENCY_EXPLORE_GROUPS.get(normalized_group)
        safe_limit = max(1, min(limit, 50))
        safe_page = max(1, page)

        pairs_response = await self.list_pairs(search=search, brl_only=True)
        pairs = pairs_response.pairs

        if group_codes:
            pairs = [pair for pair in pairs if pair.pair.split("-")[0] in group_codes]

        total = len(pairs)
        total_pages = max(1, (total + safe_limit - 1) // safe_limit)
        safe_page = min(safe_page, total_pages)
        start = (safe_page - 1) * safe_limit
        page_pairs = pairs[start : start + safe_limit]

        if not page_pairs:
            return CurrencyExploreResponse(
                items=[],
                count=0,
                total=total,
                page=safe_page,
                total_pages=total_pages,
                group=normalized_group,
            )

        rates = await self._client.get_currency_rates([pair.pair for pair in page_pairs])
        rate_by_pair = {item.pair: item for item in rates.items}

        items: list[CurrencyQuote] = []
        for summary in page_pairs:
            quote = rate_by_pair.get(summary.pair)
            if quote is not None:
                items.append(quote)
                continue
            from_currency, _, to_currency = summary.pair.partition("-")
            items.append(
                CurrencyQuote(
                    pair=summary.pair,
                    name=summary.name,
                    from_currency=from_currency,
                    to_currency=to_currency,
                )
            )

        return CurrencyExploreResponse(
            items=items,
            count=len(items),
            total=total,
            page=safe_page,
            total_pages=total_pages,
            group=normalized_group,
        )

    async def get_rate(self, pair: str) -> CurrencyQuote:
        normalized = normalize_currency_pair(pair)
        cache_key = f"rate:{normalized}"
        cached = self._rates_cache.get(cache_key)
        if cached and cached.items:
            return cached.items[0]

        result = await self._client.get_currency_rates([normalized])
        if not result.items:
            from app.core.exceptions import UpstreamError

            raise UpstreamError("Par de moedas não encontrado", status_code=404)

        self._rates_cache.set(cache_key, result)
        return result.items[0]

    async def get_history(
        self,
        pair: str,
        *,
        limit: int = 252,
        start: str | None = None,
        end: str | None = None,
    ) -> CurrencyHistoryResponse:
        normalized = normalize_currency_pair(pair)
        cache_key = f"history:{normalized}:{limit}:{start or ''}:{end or ''}"
        cached = self._history_cache.get(cache_key)
        if cached:
            return cached

        result = await self._client.get_currency_history(
            normalized,
            limit=limit,
            start=start,
            end=end,
        )
        self._history_cache.set(cache_key, result)
        return result


currency_service = CurrencyService()
