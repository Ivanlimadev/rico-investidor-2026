from app.clients.brapi.client import BrapiClient
from app.clients.brapi.models import BrazilMacroResponse, DictionaryResponse
from app.config import settings
from app.core.cache import TtlCache


class MacroService:
    def __init__(self, client: BrapiClient | None = None) -> None:
        self._client = client or BrapiClient()
        ttl = settings.quote_cache_ttl_seconds * 6
        self._macro_cache: TtlCache[BrazilMacroResponse] = TtlCache(ttl)
        self._dictionary_cache: TtlCache[DictionaryResponse] = TtlCache(ttl)

    async def get_brazil_macro(self) -> BrazilMacroResponse:
        cached = self._macro_cache.get("brazil")
        if cached:
            return cached

        result = await self._client.get_brazil_macro()
        self._macro_cache.set("brazil", result)
        return result

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
