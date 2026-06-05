from dataclasses import replace

from app.clients.brapi.client import BrapiClient
from app.clients.brapi.fii_catalog import (
    _matches_filters,
    parse_screener_params,
    sort_screener_items,
)
from app.config import settings
from app.core.cache import TtlCache
from app.domain.fii.models import (
    FiiCandlesResponse,
    FiiDetail,
    FiiDistributions,
    FiiHistoryResponse,
    FiiListItem,
    FiiListResponse,
    FiiSearchResponse,
    FiiScreenerResponse,
    FiiTenantsResponse,
)
from app.domain.fii.ticker import normalize_fii_ticker
from app.domain.home.presets import FEATURED_FII_TICKERS
from app.providers.fii_providers import FiiCapability, fii_provider_for
from app.providers.registry import AssetClass, DataProvider, provider_for
from app.services.br_proventos_service import br_proventos_service


class FiiService:
    """FIIs — cotação e relatórios via Brapi; proventos via Bolsai (fallback Brapi)."""

    def __init__(self, brapi_client: BrapiClient | None = None) -> None:
        self._brapi = brapi_client or BrapiClient()
        self._proventos = br_proventos_service
        max_entries = settings.cache_max_entries
        self._list_cache: TtlCache[FiiListResponse] = TtlCache(
            settings.fii_cache_ttl_seconds, max_entries=max_entries
        )
        self._detail_cache: TtlCache[FiiDetail] = TtlCache(
            settings.fii_cache_ttl_seconds, max_entries=max_entries
        )
        self._distributions_cache: TtlCache[FiiDistributions] = TtlCache(
            settings.fii_cache_ttl_seconds * 4, max_entries=max_entries
        )
        self._history_cache: TtlCache[FiiHistoryResponse] = TtlCache(
            settings.fii_cache_ttl_seconds * 4, max_entries=max_entries
        )
        self._candles_cache: TtlCache[FiiCandlesResponse] = TtlCache(
            settings.fii_cache_ttl_seconds * 2, max_entries=max_entries
        )
        self._catalog_cache: TtlCache[list[FiiListItem]] = TtlCache(
            settings.fii_fund_catalog_ttl_seconds, max_entries=8
        )
        self._screener_cache: TtlCache[FiiScreenerResponse] = TtlCache(
            settings.fii_cache_ttl_seconds, max_entries=max_entries
        )

    @staticmethod
    def provider() -> DataProvider:
        return provider_for(AssetClass.FII)

    async def list_fiis(self, *, limit: int = 500, offset: int = 0) -> FiiListResponse:
        bolsai_tag = ":bolsai" if self._proventos.uses_bolsai else ""
        cache_key = f"list:{limit}:{offset}{bolsai_tag}"
        cached = self._list_cache.get(cache_key)
        if cached:
            return cached

        if self._proventos.uses_bolsai:
            result = await self._list_fiis_bolsai(limit=limit, offset=offset)
            if result is not None:
                self._list_cache.set(cache_key, result)
                return result

        result = await self._brapi.list_fiis(limit=limit, offset=offset)
        self._list_cache.set(cache_key, result)
        return result

    async def load_catalog_tickers(self) -> list[str]:
        catalog = await self._load_catalog()
        return [item.ticker.upper() for item in catalog if item.ticker]

    async def _load_catalog(self) -> list[FiiListItem]:
        cache_key = "all:bolsai" if self._proventos.uses_bolsai else "all"
        cached = self._catalog_cache.get(cache_key)
        if cached:
            return cached

        if self._proventos.uses_bolsai:
            items = await self._load_bolsai_catalog()
            if items:
                self._catalog_cache.set(cache_key, items)
                return items

        items = await self._brapi.load_fii_catalog_light()
        self._catalog_cache.set(cache_key, items)
        return items

    async def search_fiis(self, query: str, *, limit: int = 20) -> FiiSearchResponse:
        q = query.strip().lower()
        catalog = await self._load_catalog()

        if not q:
            return FiiSearchResponse(
                query=query,
                count=min(limit, len(catalog)),
                total=len(catalog),
                fiis=catalog[:limit],
            )

        matches = [
            item
            for item in catalog
            if self._matches_fii_search(q, item.ticker, item.name)
        ]

        return FiiSearchResponse(
            query=query,
            count=min(limit, len(matches)),
            total=len(matches),
            fiis=matches[:limit],
        )

    @staticmethod
    def _matches_fii_search(q: str, ticker: str, name: str) -> bool:
        ticker_l = ticker.lower()
        name_l = name.lower()
        if q in ticker_l or q in name_l:
            return True
        if len(q) >= 4 and q[:4].isalpha() and ticker_l.startswith(q[:4]):
            return True
        return False

    async def get_fii(self, ticker: str) -> FiiDetail:
        normalized = normalize_fii_ticker(ticker)
        cache_key = f"detail:{normalized}"
        cached = self._detail_cache.get(cache_key)
        if cached:
            return cached

        result = await self._get_fii_detail_hybrid(normalized)
        self._detail_cache.set(cache_key, result)
        return result

    async def _get_fii_detail_hybrid(self, ticker: str) -> FiiDetail:
        if self._proventos.uses_bolsai:
            try:
                payload = await self._proventos._bolsai.get_fii(ticker)
                if payload:
                    from app.clients.bolsai.fii_mapper import map_fii_detail_from_bolsai

                    mapped = map_fii_detail_from_bolsai(payload)
                    if mapped is not None:
                        return await self._proventos.enrich_fii_detail(mapped)
            except Exception:
                pass

        result = await self._brapi.get_fii_detail(ticker)
        return await self._proventos.enrich_fii_detail(result)

    async def get_distributions(self, ticker: str, *, years: int = 5) -> FiiDistributions:
        normalized = normalize_fii_ticker(ticker)
        div_source = "bolsai" if self._proventos.uses_bolsai else "brapi"
        cache_key = f"distributions:{normalized}:{years}:{div_source}"
        cached = self._distributions_cache.get(cache_key)
        if cached:
            return cached

        detail = self._detail_cache.get(f"detail:{normalized}")
        result = await self._proventos.get_fii_distributions(
            normalized,
            years=years,
            name=detail.name if detail else None,
            close_price=detail.close_price if detail else None,
            dividend_yield_ttm=detail.dividend_yield_ttm if detail else None,
        )
        self._distributions_cache.set(cache_key, result)
        return result

    async def get_history(self, ticker: str, *, limit: int = 24) -> FiiHistoryResponse:
        normalized = normalize_fii_ticker(ticker)
        cache_key = f"history:{normalized}:{limit}"
        cached = self._history_cache.get(cache_key)
        if cached:
            return cached

        detail = self._detail_cache.get(f"detail:{normalized}")
        result = await self._brapi.get_fii_history(
            normalized,
            limit=limit,
            name=detail.name if detail else None,
        )
        self._history_cache.set(cache_key, result)
        return result

    async def get_candles(
        self,
        ticker: str,
        *,
        limit: int = 252,
        start: str | None = None,
        end: str | None = None,
    ) -> FiiCandlesResponse:
        normalized = normalize_fii_ticker(ticker)
        cache_key = f"candles:{normalized}:{limit}:{start}:{end}"
        cached = self._candles_cache.get(cache_key)
        if cached:
            return cached

        result = await self._brapi.get_fii_candles(
            normalized,
            limit=limit,
            start=start,
            end=end,
        )
        self._candles_cache.set(cache_key, result)
        return result

    async def get_tenants(self, ticker: str) -> FiiTenantsResponse:
        """Inquilinos não disponíveis na Brapi — retorna vazio."""
        normalized = normalize_fii_ticker(ticker)
        return FiiTenantsResponse(ticker=normalized, count=0, sectors=[], provider="brapi")

    async def screen_fiis(self, params: dict[str, str]) -> FiiScreenerResponse:
        bolsai_tag = ":bolsai" if self._proventos.uses_bolsai else ""
        cache_key = "screener:" + ":".join(f"{k}={params[k]}" for k in sorted(params)) + bolsai_tag
        cached = self._screener_cache.get(cache_key)
        if cached:
            return cached

        if self._proventos.uses_bolsai:
            try:
                result = await self._screen_fiis_bolsai(params)
                self._screener_cache.set(cache_key, result)
                return result
            except Exception:
                pass

        result = await self._brapi.screen_fiis(params)
        self._screener_cache.set(cache_key, result)
        return result

    async def _load_bolsai_catalog(self) -> list[FiiListItem]:
        from app.clients.bolsai.fii_screener_mapper import map_bolsai_fii_list_row

        items: list[FiiListItem] = []
        offset = 0
        page_size = 100
        total = None
        while total is None or offset < total:
            payload = await self._proventos._bolsai.list_fiis(limit=page_size, offset=offset)
            if not payload:
                break
            rows = payload.get("fiis") or []
            if not isinstance(rows, list) or not rows:
                break
            for row in rows:
                mapped = map_bolsai_fii_list_row(row)
                if mapped is not None:
                    items.append(mapped)
            total = int(payload.get("total") or len(items))
            offset += len(rows)
            if len(rows) < page_size:
                break
        return items

    async def _list_fiis_bolsai(self, *, limit: int, offset: int) -> FiiListResponse | None:
        catalog = await self._load_catalog()
        if not catalog:
            return None
        page = catalog[offset : offset + limit]
        return FiiListResponse(
            count=len(page),
            total=len(catalog),
            fiis=page,
            provider="hybrid",
        )

    async def _screen_fiis_bolsai(self, params: dict[str, str]) -> FiiScreenerResponse:
        from app.clients.bolsai.fii_screener_mapper import (
            build_bolsai_fii_screener_params,
            map_bolsai_fii_screener,
            map_bolsai_fii_screener_row,
        )

        filters = parse_screener_params(params)
        search_matches: set[str] | None = None
        if filters.search:
            catalog = await self._load_catalog()
            query = filters.search.lower()
            search_matches = {
                item.ticker
                for item in catalog
                if query in item.ticker.lower() or query in item.name.lower()
            }
            if not search_matches:
                return FiiScreenerResponse(
                    data=[],
                    count=0,
                    total=0,
                    offset=filters.offset,
                    limit=filters.limit,
                    provider="hybrid",
                )
            if not filters.needs_indicators:
                matches = [item for item in catalog if item.ticker in search_matches]
                page = matches[filters.offset : filters.offset + filters.limit]
                return FiiScreenerResponse(
                    data=[
                        FiiScreenerItem(
                            ticker=item.ticker,
                            name=item.name,
                            segment=item.segment,
                            management_type=item.management_type,
                            total_shareholders=item.total_shareholders,
                            provider="bolsai",
                        )
                        for item in page
                    ],
                    count=len(page),
                    total=len(matches),
                    offset=filters.offset,
                    limit=filters.limit,
                    provider="hybrid",
                )

        fetch_filters = filters
        if search_matches is not None and filters.needs_indicators:
            fetch_filters = replace(filters, offset=0, limit=500)

        screener_params = build_bolsai_fii_screener_params(fetch_filters)
        payload = await self._proventos._bolsai.get_fii_screener(params=screener_params)
        if not payload:
            raise RuntimeError("Bolsai FII screener vazio")
        result = map_bolsai_fii_screener(payload, filters=fetch_filters)

        if search_matches is not None and filters.needs_indicators:
            rows = payload.get("data") or []
            items = []
            for row in rows:
                mapped = map_bolsai_fii_screener_row(row)
                if mapped is not None and mapped.ticker in search_matches:
                    items.append(mapped)
            filtered = [item for item in items if _matches_filters(item, filters)]
            sorted_items = sort_screener_items(filtered, sort=filters.sort, order=filters.order)
            page = sorted_items[filters.offset : filters.offset + filters.limit]
            result = FiiScreenerResponse(
                data=page,
                count=len(page),
                total=len(sorted_items),
                offset=filters.offset,
                limit=filters.limit,
                provider="hybrid",
            )

        return await self._enrich_fii_screener_quotes_from_brapi(result)

    async def _enrich_fii_screener_quotes_from_brapi(
        self,
        result: FiiScreenerResponse,
    ) -> FiiScreenerResponse:
        tickers = [item.ticker for item in result.data]
        if not tickers:
            return result
        try:
            raw_items = await self._brapi.get_quotes_raw(tickers)
        except Exception:
            return result
        by_symbol: dict[str, dict] = {}
        for raw in raw_items:
            symbol = str(raw.get("symbol") or raw.get("stock") or "").upper().strip()
            if symbol:
                by_symbol[symbol] = raw
        items = []
        for item in result.data:
            raw = by_symbol.get(item.ticker)
            if not raw:
                items.append(item)
                continue
            price_raw = raw.get("regularMarketPrice", raw.get("close"))
            items.append(
                item.model_copy(
                    update={
                        "close_price": float(price_raw) if price_raw is not None else item.close_price,
                    }
                )
            )
        return result.model_copy(update={"data": items})

    async def count_fiis(self) -> int:
        catalog = await self._load_catalog()
        return len(catalog)

    async def featured_fiis(self) -> FiiScreenerResponse:
        cache_key = "featured:home"
        cached = self._screener_cache.get(cache_key)
        if cached:
            return cached

        result = await self._brapi.get_featured_fiis(FEATURED_FII_TICKERS)
        self._screener_cache.set(cache_key, result)
        return result

    def capability_providers(self) -> dict[str, str]:
        return {cap.value: fii_provider_for(cap).value for cap in FiiCapability}


fii_service = FiiService()
