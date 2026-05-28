from app.clients.binance.client import BinanceClient
import asyncio

from app.clients.binance.crypto_mapper import merge_book_into_quote, normalize_crypto_symbol
from app.config import settings
from app.core.cache import TtlCache
from app.core.exceptions import UpstreamError
from app.domain.crypto.models import (
    CryptoAvailableResponse,
    CryptoCandlesResponse,
    CryptoExploreResponse,
    CryptoHistoryPoint,
    CryptoHistoryResponse,
    CryptoListResponse,
    CryptoMarketSnapshot,
    CryptoMoversResponse,
    CryptoOrderBook,
    CryptoRecentTradesResponse,
    CryptoQuote,
)
from app.domain.crypto.presets import (
    CRYPTO_EXPLORE_GROUPS,
    FEATURED_CRYPTO_SYMBOLS,
    MAX_MOVER_LIMIT,
    MIN_MOVER_QUOTE_VOLUME_USDT,
    MOVER_STABLECOINS,
)


class CryptoService:
    def __init__(self, client: BinanceClient | None = None) -> None:
        self._client = client or BinanceClient()
        ttl = settings.quote_cache_ttl_seconds
        self._rates_cache: TtlCache[CryptoListResponse] = TtlCache(ttl)
        self._available_cache: TtlCache[CryptoAvailableResponse] = TtlCache(ttl * 4)
        self._history_cache: TtlCache[CryptoHistoryResponse] = TtlCache(ttl * 2)
        self._movers_cache: TtlCache[CryptoMoversResponse] = TtlCache(ttl)

    def _order_quotes(self, symbols: list[str], quotes: CryptoListResponse) -> list[CryptoQuote]:
        by_symbol = {item.symbol: item for item in quotes.items}
        return [by_symbol[symbol] for symbol in symbols if symbol in by_symbol]

    async def list_featured(self) -> CryptoListResponse:
        cache_key = "featured"
        cached = self._rates_cache.get(cache_key)
        if cached:
            return cached

        symbols = list(FEATURED_CRYPTO_SYMBOLS)
        rates = await self._client.get_crypto_rates(symbols)
        items = self._order_quotes(symbols, rates)
        result = CryptoListResponse(items=items, count=len(items), provider="binance")
        self._rates_cache.set(cache_key, result)
        return result

    async def list_available(self, *, search: str | None = None) -> CryptoAvailableResponse:
        cache_key = f"available:{search or ''}"
        cached = self._available_cache.get(cache_key)
        if cached:
            return cached

        result = await self._client.get_crypto_available(search=search)
        self._available_cache.set(cache_key, result)
        return result

    async def count_coins(self) -> int:
        available = await self.list_available()
        return available.count

    async def get_daily_movers(self, *, limit: int = 5) -> CryptoMoversResponse:
        safe_limit = max(1, min(limit, MAX_MOVER_LIMIT))
        cache_key = f"movers:{safe_limit}"
        cached = self._movers_cache.get(cache_key)
        if cached:
            return cached

        all_rates = await self._client.get_all_usdt_tickers()
        eligible = [
            quote
            for quote in all_rates.items
            if quote.symbol not in MOVER_STABLECOINS
            and (quote.volume or 0) >= MIN_MOVER_QUOTE_VOLUME_USDT
        ]
        gainers = sorted(
            [quote for quote in eligible if quote.change_percent > 0],
            key=lambda quote: quote.change_percent,
            reverse=True,
        )[:safe_limit]
        losers = sorted(
            [quote for quote in eligible if quote.change_percent < 0],
            key=lambda quote: quote.change_percent,
        )[:safe_limit]

        result = CryptoMoversResponse(
            gainers=gainers,
            losers=losers,
            limit=safe_limit,
            provider="binance",
        )
        self._movers_cache.set(cache_key, result)
        return result

    async def explore(
        self,
        *,
        search: str | None = None,
        group: str = "all",
        page: int = 1,
        limit: int = 30,
    ) -> CryptoExploreResponse:
        normalized_group = group.strip().lower() or "all"
        group_symbols = CRYPTO_EXPLORE_GROUPS.get(normalized_group)
        safe_limit = max(1, min(limit, 50))
        safe_page = max(1, page)

        available = await self.list_available(search=search)
        coins = available.coins

        if group_symbols:
            allowed = {normalize_crypto_symbol(symbol) for symbol in group_symbols}
            coins = [coin for coin in coins if coin in allowed]

        total = len(coins)
        total_pages = max(1, (total + safe_limit - 1) // safe_limit)
        safe_page = min(safe_page, total_pages)
        start = (safe_page - 1) * safe_limit
        page_coins = coins[start : start + safe_limit]

        if not page_coins:
            return CryptoExploreResponse(
                items=[],
                count=0,
                total=total,
                page=safe_page,
                total_pages=total_pages,
                group=normalized_group,
                provider="binance",
            )

        rates = await self._client.get_crypto_rates(page_coins)
        items = self._order_quotes(page_coins, rates)

        return CryptoExploreResponse(
            items=items,
            count=len(items),
            total=total,
            page=safe_page,
            total_pages=total_pages,
            group=normalized_group,
            provider="binance",
        )

    async def get_quote(self, symbol: str) -> CryptoQuote:
        normalized = normalize_crypto_symbol(symbol)
        cache_key = f"quote:{normalized}"
        cached = self._rates_cache.get(cache_key)
        if cached and cached.items:
            return cached.items[0]

        result = await self._client.get_crypto_rates([normalized])
        if not result.items:
            raise UpstreamError("Criptomoeda não encontrada", status_code=404)

        self._rates_cache.set(cache_key, result)
        return result.items[0]

    async def get_history(
        self,
        symbol: str,
        *,
        limit: int = 252,
        interval: str = "1d",
    ) -> CryptoHistoryResponse:
        normalized = normalize_crypto_symbol(symbol)
        cache_key = f"history:{normalized}:{interval}:{limit}"
        cached = self._history_cache.get(cache_key)
        if cached:
            return cached

        result = await self._client.get_crypto_history(normalized, limit=limit, interval=interval)
        self._history_cache.set(cache_key, result)
        return result

    async def get_candles(
        self,
        symbol: str,
        *,
        interval: str = "1d",
        limit: int = 252,
    ) -> CryptoCandlesResponse:
        normalized = normalize_crypto_symbol(symbol)
        return await self._client.get_crypto_candles(normalized, interval=interval, limit=limit)

    async def get_candles_preset(self, symbol: str, *, preset: str = "1m") -> CryptoCandlesResponse:
        normalized = normalize_crypto_symbol(symbol)
        return await self._client.get_crypto_candles_preset(normalized, preset=preset)

    async def get_order_book(self, symbol: str, *, limit: int = 10) -> CryptoOrderBook:
        normalized = normalize_crypto_symbol(symbol)
        return await self._client.get_order_book(normalized, limit=limit)

    async def get_recent_trades(self, symbol: str, *, limit: int = 20) -> CryptoRecentTradesResponse:
        normalized = normalize_crypto_symbol(symbol)
        return await self._client.get_recent_trades(normalized, limit=limit)

    async def get_market_snapshot(self, symbol: str) -> CryptoMarketSnapshot:
        normalized = normalize_crypto_symbol(symbol)
        quote, book, order_book, trades = await asyncio.gather(
            self.get_quote(normalized),
            self._client.get_book_ticker(normalized),
            self.get_order_book(normalized, limit=10),
            self.get_recent_trades(normalized, limit=15),
        )
        book_quote = book.items[0] if book.items else None
        enriched = merge_book_into_quote(quote, book_quote) if book_quote else quote
        return CryptoMarketSnapshot(quote=enriched, order_book=order_book, trades=trades)


crypto_service = CryptoService()
