from app.clients.bolsai.client import BolsaiClient
from app.clients.bolsai.models import (
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
from app.clients.brapi.client import BrapiClient
from app.config import settings
from app.core.cache import TtlCache
from app.domain.fii.ticker import normalize_fii_ticker
from app.providers.fii_providers import FiiCapability, fii_provider_for
from app.providers.registry import AssetClass, DataProvider, provider_for


class FiiService:
    """
    Camada de serviço FIIs com provedores duplos.

    Brapi: indicadores, relatórios, dividendos, histórico e candles.
    Bolsai: screener, inquilinos e imóveis (top_properties).
    """

    def __init__(
        self,
        bolsai_client: BolsaiClient | None = None,
        brapi_client: BrapiClient | None = None,
    ) -> None:
        self._bolsai = bolsai_client or BolsaiClient()
        self._brapi = brapi_client or BrapiClient()
        self._list_cache: TtlCache[FiiListResponse] = TtlCache(settings.fii_cache_ttl_seconds)
        self._detail_cache: TtlCache[FiiDetail] = TtlCache(settings.fii_cache_ttl_seconds)
        self._distributions_cache: TtlCache[FiiDistributions] = TtlCache(
            settings.fii_cache_ttl_seconds * 4
        )
        self._history_cache: TtlCache[FiiHistoryResponse] = TtlCache(
            settings.fii_cache_ttl_seconds * 4
        )
        self._candles_cache: TtlCache[FiiCandlesResponse] = TtlCache(
            settings.fii_cache_ttl_seconds * 2
        )
        self._tenants_cache: TtlCache[FiiTenantsResponse] = TtlCache(
            settings.fii_cache_ttl_seconds * 4
        )
        self._catalog_cache: TtlCache[list[FiiListItem]] = TtlCache(
            settings.fii_cache_ttl_seconds * 2
        )
        self._screener_cache: TtlCache[FiiScreenerResponse] = TtlCache(
            settings.fii_cache_ttl_seconds
        )

    @staticmethod
    def provider() -> DataProvider:
        return provider_for(AssetClass.FII)

    async def list_fiis(self, *, limit: int = 500, offset: int = 0) -> FiiListResponse:
        cache_key = f"list:{limit}:{offset}"
        cached = self._list_cache.get(cache_key)
        if cached:
            return cached

        result = await self._bolsai.list_fiis(limit=limit, offset=offset)
        self._list_cache.set(cache_key, result)
        return result

    async def _load_catalog(self) -> list[FiiListItem]:
        cached = self._catalog_cache.get("all")
        if cached:
            return cached

        items: list[FiiListItem] = []
        offset = 0
        page_size = 500
        total = None

        while True:
            page = await self.list_fiis(limit=page_size, offset=offset)
            items.extend(page.fiis)
            total = page.total
            offset += page.count
            if offset >= total or page.count == 0:
                break

        self._catalog_cache.set("all", items)
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
            if q in item.ticker.lower() or q in item.name.lower()
        ]

        return FiiSearchResponse(
            query=query,
            count=min(limit, len(matches)),
            total=len(matches),
            fiis=matches[:limit],
        )

    async def get_fii(self, ticker: str) -> FiiDetail:
        normalized = normalize_fii_ticker(ticker)
        cache_key = f"detail:{normalized}"
        cached = self._detail_cache.get(cache_key)
        if cached:
            return cached

        bolsai_detail = await self._bolsai.get_fii(normalized)
        try:
            result = await self._brapi.build_fii_detail(normalized, bolsai_detail)
        except Exception:
            result = bolsai_detail

        self._detail_cache.set(cache_key, result)
        return result

    async def get_distributions(self, ticker: str, *, years: int = 5) -> FiiDistributions:
        normalized = normalize_fii_ticker(ticker)
        cache_key = f"distributions:{normalized}:{years}"
        cached = self._distributions_cache.get(cache_key)
        if cached:
            return cached

        try:
            result = await self._brapi.get_fii_distributions(normalized, years=years)
        except Exception:
            result = await self._bolsai.get_fii_distributions(normalized, years=years)

        self._distributions_cache.set(cache_key, result)
        return result

    async def get_history(self, ticker: str, *, limit: int = 24) -> FiiHistoryResponse:
        normalized = normalize_fii_ticker(ticker)
        cache_key = f"history:{normalized}:{limit}"
        cached = self._history_cache.get(cache_key)
        if cached:
            return cached

        try:
            result = await self._brapi.get_fii_history(normalized, limit=limit)
        except Exception:
            result = await self._bolsai.get_fii_history(normalized, limit=limit)

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

        try:
            result = await self._brapi.get_fii_candles(
                normalized,
                limit=limit,
                start=start,
                end=end,
            )
        except Exception:
            result = await self._bolsai.get_stock_candles(
                normalized,
                limit=limit,
                start=start,
                end=end,
            )

        self._candles_cache.set(cache_key, result)
        return result

    async def get_tenants(self, ticker: str) -> FiiTenantsResponse:
        normalized = normalize_fii_ticker(ticker)
        cache_key = f"tenants:{normalized}"
        cached = self._tenants_cache.get(cache_key)
        if cached:
            return cached

        result = await self._bolsai.get_fii_tenants(normalized)
        self._tenants_cache.set(cache_key, result)
        return result

    async def screen_fiis(self, params: dict[str, str]) -> FiiScreenerResponse:
        cache_key = "screener:" + ":".join(f"{k}={params[k]}" for k in sorted(params))
        cached = self._screener_cache.get(cache_key)
        if cached:
            return cached

        result = await self._bolsai.screen_fiis(params)
        self._screener_cache.set(cache_key, result)
        return result

    async def count_fiis(self) -> int:
        catalog = await self._load_catalog()
        return len(catalog)

    def capability_providers(self) -> dict[str, str]:
        return {cap.value: fii_provider_for(cap).value for cap in FiiCapability}


fii_service = FiiService()
