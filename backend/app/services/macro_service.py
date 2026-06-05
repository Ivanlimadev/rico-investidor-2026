from app.clients.bolsai.client import BolsaiClient
from app.clients.bolsai.macro_mapper import merge_bolsai_macro
from app.clients.brapi.client import BrapiClient
from app.clients.brapi.models import BrazilMacroResponse, DictionaryResponse
from app.config import settings
from app.core.cache import TtlCache


class MacroService:
    def __init__(
        self,
        client: BrapiClient | None = None,
        bolsai: BolsaiClient | None = None,
    ) -> None:
        self._client = client or BrapiClient()
        self._bolsai = bolsai or BolsaiClient()
        ttl = settings.quote_cache_ttl_seconds * 6
        self._macro_cache: TtlCache[BrazilMacroResponse] = TtlCache(ttl)
        self._dictionary_cache: TtlCache[DictionaryResponse] = TtlCache(ttl)

    async def get_brazil_macro(self) -> BrazilMacroResponse:
        cache_tag = "brazil:hybrid" if self._bolsai.configured else "brazil"
        cached = self._macro_cache.get(cache_tag)
        if cached:
            return cached

        result = await self._client.get_brazil_macro()
        if self._bolsai.configured:
            result = await self._enrich_with_bolsai(result)

        self._macro_cache.set(cache_tag, result)
        return result

    async def _enrich_with_bolsai(self, base: BrazilMacroResponse) -> BrazilMacroResponse:
        try:
            selic, ipca, cdi = await self._fetch_bolsai_macro_series()
            return merge_bolsai_macro(base, selic=selic, ipca=ipca, cdi=cdi)
        except Exception:
            return base

    async def _fetch_bolsai_macro_series(self) -> tuple[dict | None, dict | None, dict | None]:
        import asyncio

        selic_task = self._bolsai.get_macro_selic()
        ipca_task = self._bolsai.get_macro_ipca()
        cdi_task = self._bolsai.get_macro_cdi()
        selic, ipca, cdi = await asyncio.gather(selic_task, ipca_task, cdi_task)
        return selic, ipca, cdi

    async def get_dictionary(self, *, category: str = "statistics") -> DictionaryResponse:
        normalized = category.strip().lower() or "statistics"
        cache_key = f"dictionary:{normalized}"
        cached = self._dictionary_cache.get(cache_key)
        if cached:
            return cached

        result = await self._client.get_dictionary(category=normalized)
        self._dictionary_cache.set(cache_key, result)
        return result


macro_service = MacroService()
