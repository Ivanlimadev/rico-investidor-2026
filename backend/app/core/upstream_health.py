from __future__ import annotations

import asyncio

import httpx

from app.config import settings
from app.core.cache import TtlCache
from app.core.http_client import get_http_client

_probe_cache: TtlCache[dict[str, object]] = TtlCache(60)


async def _probe(name: str, url: str, *, params: dict | None = None) -> dict[str, object]:
    try:
        response = await get_http_client().get(url, params=params, timeout=8.0)
        ok = response.status_code < 500
        return {
            "ok": ok,
            "status_code": response.status_code,
            "error": None if ok else response.text[:120],
        }
    except httpx.RequestError as exc:
        return {
            "ok": False,
            "status_code": None,
            "error": exc.__class__.__name__,
        }


async def upstream_connectivity() -> dict[str, object]:
    cached = _probe_cache.get("upstream")
    if cached is not None:
        return cached

    marketstack_params = None
    if settings.marketstack_api_key.strip():
        marketstack_params = {
            "access_key": settings.marketstack_api_key.strip(),
            "symbols": "AAPL",
            "limit": 1,
        }

    binance_task = _probe("binance", f"{settings.binance_base_url.rstrip('/')}/api/v3/ping")
    marketstack_task = _probe(
        "marketstack",
        f"{settings.marketstack_base_url.rstrip('/')}/eod/latest",
        params=marketstack_params,
    )
    binance, marketstack = await asyncio.gather(binance_task, marketstack_task)

    result = {
        "binance": binance,
        "marketstack": marketstack,
        "marketstack_configured": bool(settings.marketstack_api_key.strip()),
        "outbound_http_trust_env": settings.outbound_http_trust_env,
        "outbound_http_fallback_enabled": settings.outbound_http_fallback_enabled,
    }
    _probe_cache.set("upstream", result)
    return result
