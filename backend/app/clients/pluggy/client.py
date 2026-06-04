import httpx

from app.config import settings
from app.core.exceptions import NotConfiguredError, UpstreamError
from app.core.upstream_errors import log_upstream_failure, upstream_public_message


class PluggyClient:
    """Cliente HTTP da Pluggy (Open Finance)."""

    def __init__(
        self,
        client_id: str | None = None,
        client_secret: str | None = None,
        base_url: str | None = None,
    ) -> None:
        self._client_id = client_id if client_id is not None else settings.pluggy_client_id
        self._client_secret = (
            client_secret if client_secret is not None else settings.pluggy_client_secret
        )
        self._base_url = (base_url or settings.pluggy_base_url).rstrip("/")
        self._api_key: str | None = None

    def _ensure_configured(self) -> None:
        if not self._client_id or not self._client_secret:
            raise NotConfiguredError(
                "PLUGGY_CLIENT_ID e PLUGGY_CLIENT_SECRET não configurados. "
                "Defina em ~/Secrets/ricoapp1/.env"
            )

    async def _request(
        self,
        method: str,
        path: str,
        *,
        json: dict | None = None,
        params: dict | None = None,
        api_key: str | None = None,
    ) -> dict:
        url = f"{self._base_url}/{path.lstrip('/')}"
        headers: dict[str, str] = {}
        if api_key:
            headers["X-API-KEY"] = api_key

        try:
            async with httpx.AsyncClient(timeout=45.0) as client:
                response = await client.request(
                    method,
                    url,
                    headers=headers or None,
                    json=json,
                    params=params,
                )
        except httpx.RequestError as exc:
            raise UpstreamError(
                f"Falha ao conectar na Pluggy: {exc.__class__.__name__}",
                status_code=502,
            ) from exc

        if response.status_code == 401:
            raise UpstreamError("Credenciais Pluggy inválidas", status_code=502)
        if response.status_code == 403:
            raise UpstreamError("Acesso Pluggy negado", status_code=502)
        if response.status_code >= 400:
            log_upstream_failure(
                provider="Pluggy",
                status_code=response.status_code,
                url=url,
                body_snippet=response.text,
            )
            raise UpstreamError(
                upstream_public_message("Pluggy", response.status_code),
                status_code=502,
            )

        data = response.json()
        if not isinstance(data, dict):
            raise UpstreamError("Resposta Pluggy inválida", status_code=502)
        return data

    async def api_key(self) -> str:
        if self._api_key:
            return self._api_key

        self._ensure_configured()
        data = await self._request(
            "POST",
            "/auth",
            json={
                "clientId": self._client_id,
                "clientSecret": self._client_secret,
            },
        )
        key = data.get("apiKey")
        if not key:
            raise UpstreamError("Pluggy não retornou apiKey", status_code=502)
        self._api_key = key
        return key

    async def create_connect_token(self, *, client_user_id: str) -> str:
        key = await self.api_key()
        data = await self._request(
            "POST",
            "/connect_token",
            json={"options": {"clientUserId": client_user_id}},
            api_key=key,
        )
        token = data.get("accessToken")
        if not token:
            raise UpstreamError("Pluggy não retornou connect token", status_code=502)
        return token

    async def list_investments(self, item_id: str) -> list[dict]:
        key = await self.api_key()
        data = await self._request(
            "GET",
            "/investments",
            params={"itemId": item_id, "pageSize": 500},
            api_key=key,
        )
        results = data.get("results") or []
        if not isinstance(results, list):
            return []
        return [item for item in results if isinstance(item, dict)]

    async def fetch_item(self, item_id: str) -> dict:
        key = await self.api_key()
        return await self._request("GET", f"/items/{item_id}", api_key=key)
