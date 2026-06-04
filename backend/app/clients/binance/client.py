from __future__ import annotations

import httpx

from app.clients.binance.crypto_mapper import (
    encode_symbols_param,
    map_book_ticker,
    map_depth,
    map_klines,
    map_klines_candles,
    map_recent_trades,
    map_ticker_24hr_batch,
    map_usdt_catalog,
    normalize_crypto_symbol,
    to_usdt_pair,
)
from app.domain.crypto.presets import CRYPTO_NAMES, CRYPTO_CHART_PRESETS, DISPLAY_CURRENCY, VALID_KLINE_INTERVALS
from app.config import settings
from app.core.cache import TtlCache
from app.core.exceptions import UpstreamError
from app.core.upstream_errors import log_upstream_failure, upstream_public_message
from app.domain.crypto.models import (
    CryptoAvailableResponse,
    CryptoCandlesResponse,
    CryptoHistoryPoint,
    CryptoHistoryResponse,
    CryptoListResponse,
    CryptoOrderBook,
    CryptoRecentTradesResponse,
)


def _is_spot_usdt_symbol(item: dict) -> bool:
    if item.get("status") != "TRADING":
        return False
    if item.get("quoteAsset") != "USDT":
        return False
    if item.get("isSpotTradingAllowed") is False:
        return False
    base = str(item.get("baseAsset") or "")
    if base.endswith("UP") or base.endswith("DOWN"):
        return False
    return bool(item.get("symbol"))


class BinanceClient:
    """Cliente público da Binance Spot (sem API key)."""

    def __init__(self, base_url: str | None = None) -> None:
        self._base_url = (base_url or settings.binance_base_url).rstrip("/")
        ttl = settings.quote_cache_ttl_seconds * 4
        self._usdt_pairs_cache: TtlCache[list[str]] = TtlCache(ttl)
        self._all_tickers_cache: TtlCache[CryptoListResponse] = TtlCache(settings.quote_cache_ttl_seconds)

    async def _get(self, path: str, *, params: dict | None = None) -> object:
        url = f"{self._base_url}/{path.lstrip('/')}"
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.get(url, params=params)
        except httpx.RequestError as exc:
            raise UpstreamError(
                f"Falha ao conectar na Binance: {exc.__class__.__name__}",
                status_code=502,
            ) from exc

        if response.status_code == 400:
            raise UpstreamError("Par de criptomoeda inválido na Binance", status_code=404)
        if response.status_code >= 400:
            log_upstream_failure(
                provider="Binance",
                status_code=response.status_code,
                url=url,
                body_snippet=response.text,
            )
            raise UpstreamError(
                upstream_public_message("Binance", response.status_code),
                status_code=502,
            )

        return response.json()

    async def _resolve_pair(self, coin: str) -> str:
        normalized = normalize_crypto_symbol(coin)
        pair = to_usdt_pair(normalized)
        available = set(await self._list_usdt_pairs())
        if pair not in available:
            raise UpstreamError("Criptomoeda não encontrada", status_code=404)
        return pair

    async def _list_usdt_pairs(self) -> list[str]:
        cached = self._usdt_pairs_cache.get("pairs")
        if cached is not None:
            return cached

        data = await self._get("/api/v3/exchangeInfo")
        if not isinstance(data, dict):
            raise UpstreamError("Resposta Binance inválida", status_code=502)

        pairs = [
            str(item.get("symbol") or "")
            for item in data.get("symbols") or []
            if isinstance(item, dict) and _is_spot_usdt_symbol(item)
        ]
        self._usdt_pairs_cache.set("pairs", pairs)
        return pairs

    async def get_crypto_available(self, *, search: str | None = None) -> CryptoAvailableResponse:
        catalog = map_usdt_catalog(await self._list_usdt_pairs())
        if not search:
            return catalog

        query = search.strip().lower()
        if not query:
            return catalog

        filtered = [
            coin
            for coin in catalog.coins
            if query in coin.lower() or query in CRYPTO_NAMES.get(coin, "").lower()
        ]
        return CryptoAvailableResponse(coins=filtered, count=len(filtered), provider="binance")

    async def get_all_usdt_tickers(self, *, currency: str = DISPLAY_CURRENCY) -> CryptoListResponse:
        cached = self._all_tickers_cache.get("all")
        if cached is not None:
            return cached

        data = await self._get("/api/v3/ticker/24hr")
        if not isinstance(data, list):
            raise UpstreamError("Resposta Binance inválida", status_code=502)

        allowed = set(await self._list_usdt_pairs())
        filtered = [
            row
            for row in data
            if isinstance(row, dict) and str(row.get("symbol") or "") in allowed
        ]
        result = map_ticker_24hr_batch(filtered, currency=currency)
        self._all_tickers_cache.set("all", result)
        return result

    async def get_crypto_rates(self, coins: list[str], *, currency: str = DISPLAY_CURRENCY) -> CryptoListResponse:
        normalized = [normalize_crypto_symbol(coin) for coin in coins if coin.strip()]
        if not normalized:
            raise UpstreamError("Informe ao menos uma criptomoeda", status_code=400)

        available_pairs = set(await self._list_usdt_pairs())
        pairs = [to_usdt_pair(coin) for coin in normalized if to_usdt_pair(coin) in available_pairs]
        if not pairs:
            return CryptoListResponse(items=[], count=0, provider="binance")

        if len(pairs) == 1:
            data = await self._get("/api/v3/ticker/24hr", params={"symbol": pairs[0]})
            return map_ticker_24hr_batch(data, currency=currency)

        data = await self._get(
            "/api/v3/ticker/24hr",
            params={"symbols": encode_symbols_param(pairs)},
        )
        if not isinstance(data, list):
            raise UpstreamError("Resposta Binance inválida", status_code=502)
        return map_ticker_24hr_batch(data, currency=currency)

    async def get_book_ticker(self, coin: str) -> CryptoListResponse:
        pair = await self._resolve_pair(coin)
        data = await self._get("/api/v3/ticker/bookTicker", params={"symbol": pair})
        if not isinstance(data, dict):
            raise UpstreamError("Resposta Binance inválida", status_code=502)
        quote = map_book_ticker(data, symbol=coin)
        return CryptoListResponse(items=[quote], count=1, provider="binance")

    async def get_order_book(self, coin: str, *, limit: int = 10) -> CryptoOrderBook:
        pair = await self._resolve_pair(coin)
        safe_limit = max(5, min(limit, 100))
        if safe_limit not in {5, 10, 20, 50, 100, 500, 1000, 5000}:
            safe_limit = 10
        data = await self._get("/api/v3/depth", params={"symbol": pair, "limit": safe_limit})
        if not isinstance(data, dict):
            raise UpstreamError("Resposta Binance inválida", status_code=502)
        return map_depth(data, symbol=coin)

    async def get_recent_trades(self, coin: str, *, limit: int = 20) -> CryptoRecentTradesResponse:
        pair = await self._resolve_pair(coin)
        safe_limit = max(1, min(limit, 100))
        data = await self._get("/api/v3/trades", params={"symbol": pair, "limit": safe_limit})
        if not isinstance(data, list):
            raise UpstreamError("Resposta Binance inválida", status_code=502)
        return map_recent_trades(data, symbol=coin)

    async def get_crypto_history(
        self,
        coin: str,
        *,
        currency: str = DISPLAY_CURRENCY,
        limit: int = 252,
        interval: str = "1d",
    ) -> CryptoHistoryResponse:
        candles = await self.get_crypto_candles(coin, currency=currency, limit=limit, interval=interval)
        history = [CryptoHistoryPoint(date=candle.date, value=candle.close) for candle in candles.candles]

        return CryptoHistoryResponse(
            symbol=candles.symbol,
            currency=currency,
            history=history,
            count=len(history),
            provider="binance",
        )

    async def get_crypto_candles(
        self,
        coin: str,
        *,
        currency: str = DISPLAY_CURRENCY,
        limit: int = 252,
        interval: str = "1d",
    ) -> CryptoCandlesResponse:
        normalized = normalize_crypto_symbol(coin)
        pair = await self._resolve_pair(normalized)
        safe_interval = interval if interval in VALID_KLINE_INTERVALS else "1d"
        safe_limit = max(1, min(limit, 1000))
        data = await self._get(
            "/api/v3/klines",
            params={"symbol": pair, "interval": safe_interval, "limit": safe_limit},
        )
        if not isinstance(data, list):
            raise UpstreamError("Resposta Binance inválida", status_code=502)
        return map_klines_candles(
            data,
            symbol=normalized,
            currency=currency,
            interval=safe_interval,
            limit=limit,
        )

    async def get_crypto_candles_preset(
        self,
        coin: str,
        *,
        preset: str = "1m",
    ) -> CryptoCandlesResponse:
        normalized_preset = preset.strip().lower()
        interval, limit = CRYPTO_CHART_PRESETS.get(normalized_preset, ("1d", 30))
        return await self.get_crypto_candles(coin, interval=interval, limit=limit)

    async def get_usdt_brl_rate(self) -> float | None:
        """Cotação USDT/BRL na Binance (par USDTBRL)."""
        try:
            data = await self._get("/api/v3/ticker/price", params={"symbol": "USDTBRL"})
            if isinstance(data, dict) and data.get("price") is not None:
                return float(data["price"])
        except UpstreamError:
            return None
        return None
