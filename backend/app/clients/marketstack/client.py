from __future__ import annotations

import asyncio

import httpx

from app.clients.marketstack.stock_mapper import (
    map_eod_candles,
    map_eod_quotes_with_change,
    map_exchange,
    normalize_marketstack_symbol,
)
from app.config import settings
from app.core.exceptions import NotConfiguredError, UpstreamError


class MarketstackClient:
    """Cliente HTTP da Marketstack — mesma superfície para Free e Business."""

    _request_limit = asyncio.Semaphore(5)
    _retryable_status = frozenset({429, 502, 503, 504})

    def __init__(
        self,
        *,
        api_key: str | None = None,
        base_url: str | None = None,
    ) -> None:
        self._api_key = (api_key if api_key is not None else settings.marketstack_api_key).strip()
        self._base_url = (base_url or settings.marketstack_base_url).rstrip("/")

    @property
    def configured(self) -> bool:
        return bool(self._api_key)

    def _require_key(self) -> str:
        if not self._api_key:
            raise NotConfiguredError(
                "MARKETSTACK_API_KEY não configurada. Defina em backend/.env ou ~/Secrets/ricoapp1/.env."
            )
        return self._api_key

    @staticmethod
    def resolve_v2_base_url(base_url: str) -> str:
        normalized = base_url.rstrip("/")
        if normalized.endswith("/v2"):
            return normalized
        if normalized.endswith("/v1"):
            return f"{normalized[:-2]}v2"
        return "https://api.marketstack.com/v2"

    def _dividends_base_url(self) -> str:
        """Dividendos exigem API v2 (datas de pagamento/registro)."""
        return self.resolve_v2_base_url(self._base_url)

    async def _get(
        self,
        path: str,
        *,
        params: dict | None = None,
        retries: int = 2,
        base_url: str | None = None,
    ) -> dict:
        key = self._require_key()
        query = {"access_key": key, **(params or {})}
        url = f"{(base_url or self._base_url).rstrip('/')}/{path.lstrip('/')}"

        last_error: UpstreamError | None = None
        for attempt in range(retries + 1):
            try:
                async with self._request_limit:
                    async with httpx.AsyncClient(timeout=30.0) as client:
                        response = await client.get(url, params=query)
            except httpx.RequestError as exc:
                last_error = UpstreamError(
                    f"Falha ao conectar na Marketstack: {exc.__class__.__name__}",
                    status_code=502,
                )
                if attempt < retries:
                    await asyncio.sleep(0.4 * (attempt + 1))
                    continue
                raise last_error from exc

            if response.status_code == 401:
                raise UpstreamError("Marketstack: chave de API inválida", status_code=502)
            if response.status_code == 403:
                raise UpstreamError(
                    "Marketstack: recurso indisponível no plano atual",
                    status_code=502,
                )
            if response.status_code in self._retryable_status and attempt < retries:
                await asyncio.sleep(0.5 * (attempt + 1))
                continue
            if response.status_code == 429:
                raise UpstreamError("Marketstack: cota mensal esgotada", status_code=503)
            if response.status_code >= 400:
                raise UpstreamError(
                    f"Erro Marketstack ({response.status_code}): {response.text[:200]}",
                    status_code=502,
                )

            payload = response.json()
            if not isinstance(payload, dict):
                raise UpstreamError("Resposta inválida da Marketstack", status_code=502)

            error = payload.get("error")
            if isinstance(error, dict):
                message = str(error.get("message") or "Erro Marketstack")
                code = int(error.get("code") or 502)
                status = 503 if code == 429 else 502
                last_error = UpstreamError(message, status_code=status)
                if code in {429, 502, 503, 504} and attempt < retries:
                    await asyncio.sleep(0.5 * (attempt + 1))
                    continue
                raise last_error

            return payload

        if last_error is not None:
            raise last_error
        raise UpstreamError("Erro Marketstack", status_code=502)

    @staticmethod
    def _data(payload: dict) -> list[dict]:
        raw = payload.get("data")
        if isinstance(raw, list):
            return [item for item in raw if isinstance(item, dict)]
        if isinstance(raw, dict):
            return [raw]
        return []

    @staticmethod
    def _exchange_ticker_rows(payload: dict) -> list[dict]:
        raw = payload.get("data")
        if isinstance(raw, dict):
            tickers = raw.get("tickers")
            if isinstance(tickers, list):
                return [item for item in tickers if isinstance(item, dict)]
        return MarketstackClient._data(payload)

    @staticmethod
    def _normalize_symbols(symbols: list[str]) -> list[str]:
        return [normalize_marketstack_symbol(symbol) for symbol in symbols if symbol.strip()]

    async def get_eod_latest(
        self,
        symbols: list[str],
        *,
        exchange: str | None = None,
    ) -> list[dict]:
        normalized = self._normalize_symbols(symbols)
        if not normalized:
            return []

        params: dict[str, str | int] = {"symbols": ",".join(normalized)}
        if exchange:
            params["exchange"] = exchange.upper()
        payload = await self._get("eod/latest", params=params)
        return self._data(payload)

    async def get_eod_range(
        self,
        symbols: list[str],
        *,
        date_from: str,
        date_to: str | None = None,
        exchange: str | None = None,
        limit: int = 1000,
    ) -> list[dict]:
        normalized = self._normalize_symbols(symbols)
        if not normalized:
            return []

        params: dict[str, str | int] = {
            "symbols": ",".join(normalized),
            "date_from": date_from,
            "limit": max(1, min(limit, 1000)),
            "sort": "DESC",
        }
        if date_to:
            params["date_to"] = date_to
        if exchange:
            params["exchange"] = exchange.upper()

        payload = await self._get("eod", params=params)
        return self._data(payload)

    async def list_exchanges(self, *, limit: int = 100, offset: int = 0) -> list[dict]:
        payload = await self._get(
            "exchanges",
            params={"limit": max(1, min(limit, 100)), "offset": max(0, offset)},
        )
        return self._data(payload)

    async def list_exchange_tickers(
        self,
        mic: str,
        *,
        limit: int = 100,
        offset: int = 0,
        search: str | None = None,
    ) -> tuple[list[dict], dict]:
        params: dict[str, str | int] = {
            "limit": max(1, min(limit, 100)),
            "offset": max(0, offset),
        }
        if search:
            params["search"] = search.strip()

        payload = await self._get(f"exchanges/{mic.upper()}/tickers", params=params)
        pagination = payload.get("pagination")
        return self._exchange_ticker_rows(payload), pagination if isinstance(pagination, dict) else {}

    async def get_exchange_eod(
        self,
        mic: str,
        *,
        limit: int = 30,
        offset: int = 0,
    ) -> tuple[list[dict], dict]:
        params: dict[str, str | int] = {
            "limit": max(1, min(limit, 100)),
            "offset": max(0, offset),
            "sort": "DESC",
        }
        payload = await self._get(f"exchanges/{mic.upper()}/eod", params=params)
        pagination = payload.get("pagination")
        return self._data(payload), pagination if isinstance(pagination, dict) else {}

    async def get_exchange(self, mic: str) -> dict | None:
        payload = await self._get(f"exchanges/{mic.upper()}")
        data = payload.get("data")
        return data if isinstance(data, dict) else None

    @staticmethod
    def _unwrap_ticker_payload(payload: dict) -> dict | None:
        if isinstance(payload.get("symbol"), str):
            return payload
        data = payload.get("data")
        return data if isinstance(data, dict) else None

    async def get_ticker(self, symbol: str) -> dict | None:
        payload = await self._get(f"tickers/{normalize_marketstack_symbol(symbol)}")
        return self._unwrap_ticker_payload(payload)

    async def get_ticker_eod_latest(self, symbol: str) -> dict | None:
        payload = await self._get(f"tickers/{normalize_marketstack_symbol(symbol)}/eod/latest")
        return self._unwrap_ticker_payload(payload)

    async def get_ticker_dividends(
        self,
        symbol: str,
        *,
        limit: int = 12,
        offset: int = 0,
    ) -> tuple[list[dict], dict]:
        api_symbol = normalize_marketstack_symbol(symbol)
        payload = await self._get(
            f"tickers/{api_symbol}/dividends",
            params={"limit": max(1, min(limit, 100)), "offset": max(0, offset), "sort": "DESC"},
            base_url=self._dividends_base_url(),
        )
        pagination = payload.get("pagination")
        return self._data(payload), pagination if isinstance(pagination, dict) else {}

    async def get_ticker_dividends_paginated(
        self,
        symbol: str,
        *,
        limit: int = 100,
    ) -> tuple[list[dict], dict]:
        safe_limit = max(1, min(limit, 500))
        collected: list[dict] = []
        offset = 0
        pagination: dict = {}

        while len(collected) < safe_limit:
            batch_size = min(100, safe_limit - len(collected))
            batch, pagination = await self.get_ticker_dividends(
                symbol,
                limit=batch_size,
                offset=offset,
            )
            if not batch:
                break
            collected.extend(batch)
            offset += len(batch)
            total = pagination.get("total")
            if len(batch) < batch_size:
                break
            if total is not None:
                try:
                    if offset >= int(total):
                        break
                except (TypeError, ValueError):
                    pass

        return collected[:safe_limit], pagination

    async def get_ticker_splits_paginated(
        self,
        symbol: str,
        *,
        limit: int = 100,
    ) -> tuple[list[dict], dict]:
        safe_limit = max(1, min(limit, 500))
        collected: list[dict] = []
        offset = 0
        pagination: dict = {}

        while len(collected) < safe_limit:
            batch_size = min(100, safe_limit - len(collected))
            batch, pagination = await self.get_ticker_splits(
                symbol,
                limit=batch_size,
                offset=offset,
            )
            if not batch:
                break
            collected.extend(batch)
            offset += len(batch)
            total = pagination.get("total")
            if len(batch) < batch_size:
                break
            if total is not None:
                try:
                    if offset >= int(total):
                        break
                except (TypeError, ValueError):
                    pass

        return collected[:safe_limit], pagination

    async def search_tickers_v2(
        self,
        *,
        search: str,
        limit: int = 25,
        offset: int = 0,
    ) -> tuple[list[str], dict]:
        try:
            payload = await self._get_v2(
                "tickerslist",
                params={
                    "search": search.strip(),
                    "limit": max(1, min(limit, 100)),
                    "offset": max(0, offset),
                },
            )
        except UpstreamError:
            return [], {}

        rows = self._data(payload)
        symbols: list[str] = []
        for row in rows:
            ticker = row.get("ticker") or row.get("symbol")
            if isinstance(ticker, str) and ticker.strip():
                symbols.append(ticker.strip().upper())
        pagination = payload.get("pagination")
        return symbols, pagination if isinstance(pagination, dict) else {}

    @property
    def _v2_base_url(self) -> str:
        if self._base_url.endswith("/v1"):
            return f"{self._base_url[:-3]}/v2"
        return f"{self._base_url}/v2"

    async def _get_v2(self, path: str, *, params: dict | None = None, retries: int = 2) -> dict:
        key = self._require_key()
        query = {"access_key": key, **(params or {})}
        url = f"{self._v2_base_url}/{path.lstrip('/')}"

        last_error: UpstreamError | None = None
        for attempt in range(retries + 1):
            try:
                async with self._request_limit:
                    async with httpx.AsyncClient(timeout=30.0) as client:
                        response = await client.get(url, params=query)
            except httpx.RequestError as exc:
                last_error = UpstreamError(
                    f"Falha ao conectar na Marketstack: {exc.__class__.__name__}",
                    status_code=502,
                )
                if attempt < retries:
                    await asyncio.sleep(0.4 * (attempt + 1))
                    continue
                raise last_error from exc

            if response.status_code in {401, 403, 404}:
                raise UpstreamError(
                    "Marketstack: recurso indisponível no plano atual",
                    status_code=502,
                )
            if response.status_code in self._retryable_status and attempt < retries:
                await asyncio.sleep(0.5 * (attempt + 1))
                continue
            if response.status_code == 429:
                raise UpstreamError("Marketstack: cota mensal esgotada", status_code=503)
            if response.status_code >= 400:
                raise UpstreamError(
                    f"Erro Marketstack ({response.status_code}): {response.text[:200]}",
                    status_code=502,
                )

            payload = response.json()
            if not isinstance(payload, dict):
                raise UpstreamError("Resposta inválida da Marketstack", status_code=502)

            error = payload.get("error")
            if isinstance(error, dict):
                message = str(error.get("message") or "Erro Marketstack")
                code = int(error.get("code") or 502)
                status = 503 if code == 429 else 502
                last_error = UpstreamError(message, status_code=status)
                if code in {429, 502, 503, 504} and attempt < retries:
                    await asyncio.sleep(0.5 * (attempt + 1))
                    continue
                raise last_error

            return payload

        if last_error is not None:
            raise last_error
        raise UpstreamError("Erro Marketstack", status_code=502)

    async def get_ticker_info_v2(self, symbol: str) -> dict | None:
        api_symbol = normalize_marketstack_symbol(symbol)
        try:
            payload = await self._get_v2("tickerinfo", params={"ticker": api_symbol})
        except UpstreamError:
            return None
        data = payload.get("data")
        return data if isinstance(data, dict) else payload if isinstance(payload, dict) else None

    async def get_ticker_splits(
        self,
        symbol: str,
        *,
        limit: int = 12,
        offset: int = 0,
    ) -> tuple[list[dict], dict]:
        api_symbol = normalize_marketstack_symbol(symbol)
        payload = await self._get(
            f"tickers/{api_symbol}/splits",
            params={"limit": max(1, min(limit, 100)), "offset": max(0, offset), "sort": "DESC"},
        )
        pagination = payload.get("pagination")
        return self._data(payload), pagination if isinstance(pagination, dict) else {}

    async def get_ticker_eod(
        self,
        symbol: str,
        *,
        date_from: str,
        date_to: str | None = None,
        exchange: str | None = None,
        limit: int = 1000,
    ) -> list[dict]:
        return await self.get_eod_range(
            [symbol],
            date_from=date_from,
            date_to=date_to,
            exchange=exchange,
            limit=limit,
        )

    async def get_intraday_latest(
        self,
        symbols: list[str],
        *,
        interval: str = "5min",
        exchange: str | None = None,
    ) -> list[dict]:
        normalized = self._normalize_symbols(symbols)
        if not normalized:
            return []

        params: dict[str, str | int] = {
            "symbols": ",".join(normalized),
            "interval": interval,
        }
        if exchange:
            params["exchange"] = exchange.upper()
        payload = await self._get("intraday/latest", params=params)
        return self._data(payload)

    async def map_quotes_with_change(
        self,
        symbols: list[str],
        *,
        category: str,
        exchange: str | None = None,
        lookback_days: int = 10,
        use_intraday: bool = False,
        intraday_interval: str = "5min",
    ) -> list:
        if not symbols:
            return []

        if use_intraday:
            rows = await self.get_intraday_latest(
                symbols,
                interval=intraday_interval,
                exchange=exchange,
            )
            if rows:
                return map_eod_quotes_with_change(rows, category=category)

        from datetime import UTC, datetime, timedelta

        date_from = (datetime.now(UTC).date() - timedelta(days=max(2, lookback_days))).isoformat()
        rows = await self.get_eod_range(symbols, date_from=date_from, exchange=exchange, limit=1000)
        return map_eod_quotes_with_change(rows, category=category)

    async def map_candles(
        self,
        symbol: str,
        *,
        date_from: str,
        exchange: str | None = None,
        limit: int = 1000,
    ) -> list:
        rows = await self.get_ticker_eod(
            symbol,
            date_from=date_from,
            exchange=exchange,
            limit=limit,
        )
        return map_eod_candles(rows)

    async def map_exchanges(self) -> list:
        rows = await self.list_exchanges(limit=100)
        exchanges = [map_exchange(item) for item in rows]
        return [exchange for exchange in exchanges if exchange is not None]
