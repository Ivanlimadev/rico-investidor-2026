from app.clients.brapi.client import BrapiClient
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


class FiiService:
    """Camada de serviço FIIs — fonte única: Brapi."""

    def __init__(self, brapi_client: BrapiClient | None = None) -> None:
        self._brapi = brapi_client or BrapiClient()
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
        cache_key = f"list:{limit}:{offset}"
        cached = self._list_cache.get(cache_key)
        if cached:
            return cached

        result = await self._brapi.list_fiis(limit=limit, offset=offset)
        self._list_cache.set(cache_key, result)
        return result

    async def _load_catalog(self) -> list[FiiListItem]:
        cached = self._catalog_cache.get("all")
        if cached:
            return cached

        items = await self._brapi.load_fii_catalog_light()
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

        result = await self._brapi.get_fii_detail(normalized)
        self._detail_cache.set(cache_key, result)
        return result

    async def get_distributions(self, ticker: str, *, years: int = 5) -> FiiDistributions:
        normalized = normalize_fii_ticker(ticker)
        cache_key = f"distributions:{normalized}:{years}"
        cached = self._distributions_cache.get(cache_key)
        if cached:
            return cached

        detail = self._detail_cache.get(f"detail:{normalized}")
        result = await self._brapi.get_fii_distributions(
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
        cache_key = "screener:" + ":".join(f"{k}={params[k]}" for k in sorted(params))
        cached = self._screener_cache.get(cache_key)
        if cached:
            return cached

        result = await self._brapi.screen_fiis(params)
        self._screener_cache.set(cache_key, result)
        return result

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
