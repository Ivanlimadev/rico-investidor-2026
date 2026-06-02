from __future__ import annotations

import httpx

from app.config import settings
from app.core.cache import TtlCache
from app.core.exceptions import UpstreamError
from app.domain.crypto.models import CryptoFundamentals, CryptoMacroSnapshot


class CoinGeckoClient:
    """CoinGecko API pública (sem key) — fundamentos e macro."""

    def __init__(self, base_url: str | None = None) -> None:
        self._base_url = (base_url or settings.coingecko_base_url).rstrip("/")
        self._fundamentals_cache: TtlCache[CryptoFundamentals] = TtlCache(
            settings.coingecko_cache_ttl_seconds
        )
        self._global_cache: TtlCache[CryptoMacroSnapshot] = TtlCache(
            settings.crypto_macro_cache_ttl_seconds
        )

    async def _get(self, path: str, *, params: dict | None = None) -> object:
        url = f"{self._base_url}/{path.lstrip('/')}"
        try:
            async with httpx.AsyncClient(timeout=25.0) as client:
                response = await client.get(url, params=params)
        except httpx.RequestError as exc:
            raise UpstreamError(
                f"Falha ao conectar no CoinGecko: {exc.__class__.__name__}",
                status_code=502,
            ) from exc

        if response.status_code == 404:
            raise UpstreamError("Ativo não encontrado no CoinGecko", status_code=404)
        if response.status_code == 429:
            raise UpstreamError("Limite CoinGecko atingido — tente mais tarde", status_code=429)
        if response.status_code >= 400:
            raise UpstreamError(
                f"Erro CoinGecko ({response.status_code})",
                status_code=502,
            )

        return response.json()

    async def get_fundamentals(self, symbol: str) -> CryptoFundamentals:
        normalized = symbol.strip().lower()
        cache_key = f"fund:{normalized}"
        cached = self._fundamentals_cache.get(cache_key)
        if cached is not None:
            return cached

        data = await self._get(
            "/coins/markets",
            params={
                "vs_currency": "usd",
                "symbols": normalized,
                "sparkline": "false",
                "price_change_percentage": "7d,30d,1y",
            },
        )
        if not isinstance(data, list) or not data:
            empty = CryptoFundamentals()
            self._fundamentals_cache.set(cache_key, empty)
            return empty

        row = data[0] if isinstance(data[0], dict) else {}
        result = CryptoFundamentals(
            market_cap=_float(row.get("market_cap")),
            market_cap_rank=_int(row.get("market_cap_rank")),
            circulating_supply=_float(row.get("circulating_supply")),
            total_supply=_float(row.get("total_supply")),
            ath=_float(row.get("ath")),
            ath_change_percent=_float(row.get("ath_change_percentage")),
            atl=_float(row.get("atl")),
            categories=[],
        )
        self._fundamentals_cache.set(cache_key, result)
        return result

    async def get_global_macro(self) -> CryptoMacroSnapshot:
        cached = self._global_cache.get("global")
        if cached is not None:
            return cached

        data = await self._get("/global")
        if not isinstance(data, dict):
            raise UpstreamError("Resposta CoinGecko inválida", status_code=502)

        payload = data.get("data") if isinstance(data.get("data"), dict) else data
        market_cap = payload.get("total_market_cap") if isinstance(payload, dict) else None
        volume = payload.get("total_volume") if isinstance(payload, dict) else None
        dominance = payload.get("market_cap_percentage") if isinstance(payload, dict) else None

        total_cap = None
        total_vol = None
        btc_dom = None
        if isinstance(market_cap, dict):
            total_cap = _float(market_cap.get("usd"))
        if isinstance(volume, dict):
            total_vol = _float(volume.get("usd"))
        if isinstance(dominance, dict):
            btc_dom = _float(dominance.get("btc"))

        result = CryptoMacroSnapshot(
            btc_dominance=btc_dom,
            total_market_cap_usd=total_cap,
            total_volume_24h_usd=total_vol,
        )
        self._global_cache.set("global", result)
        return result


async def fetch_fear_greed() -> tuple[int | None, str | None]:
    """Fear & Greed Index — alternative.me (público)."""
    url = "https://api.alternative.me/fng/"
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.get(url, params={"limit": 1})
        if response.status_code >= 400:
            return None, None
        payload = response.json()
        rows = payload.get("data") if isinstance(payload, dict) else None
        if not isinstance(rows, list) or not rows:
            return None, None
        row = rows[0] if isinstance(rows[0], dict) else {}
        value = _int(row.get("value"))
        label = str(row.get("value_classification") or "").strip() or None
        return value, label
    except httpx.RequestError:
        return None, None


def _float(value: object) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _int(value: object) -> int | None:
    if value is None:
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None
