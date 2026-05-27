from app.clients.brapi.client import BrapiClient
from app.clients.brapi.treasury_mapper import normalize_treasury_symbol
from app.config import settings
from app.core.cache import TtlCache
from app.domain.treasury.models import TreasuryBond, TreasuryHistoryResponse, TreasuryListResponse
from app.domain.treasury.presets import FEATURED_TREASURY_SYMBOLS, TREASURY_EXPLORE_GROUPS


class TreasuryService:
    def __init__(self, client: BrapiClient | None = None) -> None:
        self._client = client or BrapiClient()
        ttl = settings.quote_cache_ttl_seconds
        self._featured_cache: TtlCache[list[TreasuryBond]] = TtlCache(ttl)
        self._list_cache: TtlCache[TreasuryListResponse] = TtlCache(ttl)
        self._bond_cache: TtlCache[TreasuryBond] = TtlCache(ttl)
        self._history_cache: TtlCache[TreasuryHistoryResponse] = TtlCache(ttl * 2)
        self._count_cache: TtlCache[int] = TtlCache(ttl * 4)

    async def list_featured(self) -> list[TreasuryBond]:
        cached = self._featured_cache.get("featured")
        if cached is not None:
            return cached

        bonds = await self._client.get_treasury_indicators(list(FEATURED_TREASURY_SYMBOLS))
        if not bonds:
            result = await self._client.get_treasury_list(limit=len(FEATURED_TREASURY_SYMBOLS))
            bonds = result.items

        self._featured_cache.set("featured", bonds)
        return bonds

    async def explore(
        self,
        *,
        search: str | None = None,
        group: str = "all",
        page: int = 1,
        limit: int = 30,
    ) -> TreasuryListResponse:
        normalized_group = group.strip().lower() or "all"
        indexer = TREASURY_EXPLORE_GROUPS.get(normalized_group)
        safe_limit = max(1, min(limit, 50))
        safe_page = max(1, page)
        cache_key = f"explore:{search or ''}:{normalized_group}:{safe_page}:{safe_limit}"
        cached = self._list_cache.get(cache_key)
        if cached:
            return cached

        result = await self._client.get_treasury_list(
            search=search,
            indexer=indexer,
            page=safe_page,
            limit=safe_limit,
        )
        result.group = normalized_group
        self._list_cache.set(cache_key, result)
        return result

    async def count_bonds(self) -> int:
        cached = self._count_cache.get("count")
        if cached is not None:
            return cached

        result = await self._client.get_treasury_list(limit=1)
        total = result.total
        self._count_cache.set("count", total)
        return total

    async def get_bond(self, symbol: str) -> TreasuryBond:
        normalized = normalize_treasury_symbol(symbol)
        cache_key = f"bond:{normalized}"
        cached = self._bond_cache.get(cache_key)
        if cached:
            return cached

        bonds = await self._client.get_treasury_indicators([normalized])
        if not bonds:
            from app.core.exceptions import UpstreamError

            raise UpstreamError("Título do Tesouro não encontrado", status_code=404)

        self._bond_cache.set(cache_key, bonds[0])
        return bonds[0]

    async def get_history(
        self,
        symbol: str,
        *,
        limit: int = 252,
        start: str | None = None,
        end: str | None = None,
    ) -> TreasuryHistoryResponse:
        normalized = normalize_treasury_symbol(symbol)
        cache_key = f"history:{normalized}:{limit}:{start or ''}:{end or ''}"
        cached = self._history_cache.get(cache_key)
        if cached:
            return cached

        result = await self._client.get_treasury_history(
            normalized,
            limit=limit,
            start=start,
            end=end,
        )
        self._history_cache.set(cache_key, result)
        return result


treasury_service = TreasuryService()
