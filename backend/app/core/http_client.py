from __future__ import annotations

import httpx

from app.config import settings

_RETRYABLE_REQUEST_ERRORS = (
    httpx.ConnectError,
    httpx.ConnectTimeout,
    httpx.ProxyError,
    httpx.NetworkError,
)

_clients: dict[bool, httpx.AsyncClient] = {}


def _client_for(trust_env: bool) -> httpx.AsyncClient:
    client = _clients.get(trust_env)
    if client is None or client.is_closed:
        client = httpx.AsyncClient(
            timeout=30.0,
            follow_redirects=True,
            trust_env=trust_env,
            limits=httpx.Limits(max_connections=40, max_keepalive_connections=20),
        )
        _clients[trust_env] = client
    return client


def _trust_env_modes() -> list[bool]:
    primary = settings.outbound_http_trust_env
    if not settings.outbound_http_fallback_enabled:
        return [primary]
    fallback = not primary
    if fallback == primary:
        return [primary]
    return [primary, fallback]


class OutboundHttpClient:
    """HTTP compartilhado com fallback direct/proxy para APIs externas."""

    async def request(self, method: str, url: str, **kwargs) -> httpx.Response:
        last_error: Exception | None = None
        for trust_env in _trust_env_modes():
            try:
                return await _client_for(trust_env).request(method, url, **kwargs)
            except _RETRYABLE_REQUEST_ERRORS as exc:
                last_error = exc
                continue
        if last_error is not None:
            raise last_error
        raise RuntimeError("Outbound HTTP request failed without a response")

    async def get(self, url: str, **kwargs) -> httpx.Response:
        return await self.request("GET", url, **kwargs)

    async def post(self, url: str, **kwargs) -> httpx.Response:
        return await self.request("POST", url, **kwargs)

    async def put(self, url: str, **kwargs) -> httpx.Response:
        return await self.request("PUT", url, **kwargs)

    async def delete(self, url: str, **kwargs) -> httpx.Response:
        return await self.request("DELETE", url, **kwargs)


_outbound_client: OutboundHttpClient | None = None


def get_http_client() -> OutboundHttpClient:
    global _outbound_client
    if _outbound_client is None:
        _outbound_client = OutboundHttpClient()
    return _outbound_client


async def close_http_client() -> None:
    global _outbound_client
    _outbound_client = None
    for trust_env, client in list(_clients.items()):
        if not client.is_closed:
            await client.aclose()
        _clients.pop(trust_env, None)
