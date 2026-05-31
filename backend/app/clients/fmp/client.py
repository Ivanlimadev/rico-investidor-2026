from __future__ import annotations

import httpx

from app.clients.marketstack.stock_mapper import fmp_api_symbol
from app.config import settings
from app.core.exceptions import UpstreamError
from app.core.http_client import get_http_client


class FmpClient:
    """Cliente da Financial Modeling Prep (plano grátis) — opcional.

    Sem chave configurada, todos os métodos retornam ``None`` para que o
    enriquecimento seja silenciosamente ignorado.
    """

    def __init__(self, *, api_key: str | None = None, base_url: str | None = None) -> None:
        self._api_key = (api_key if api_key is not None else settings.fmp_api_key).strip()
        self._base_url = (base_url or settings.fmp_base_url).rstrip("/")

    @property
    def configured(self) -> bool:
        return bool(self._api_key)

    async def get_company_profile(self, symbol: str) -> dict | None:
        """Retorna o perfil da empresa.

        Contrato:
          - ``dict`` → perfil encontrado.
          - ``None`` → não existe perfil para o símbolo (negativo definitivo).
          - levanta ``UpstreamError`` → falha transitória (rede/429/5xx) ou chave
            inválida; o chamador NÃO deve cachear negativo.
        """
        if not self._api_key:
            return None

        api_symbol = fmp_api_symbol(symbol)
        if not api_symbol:
            return None

        url = f"{self._base_url}/profile"
        params = {"symbol": api_symbol, "apikey": self._api_key}
        try:
            client = get_http_client()
            response = await client.get(url, params=params, timeout=15.0)
        except httpx.RequestError as exc:
            raise UpstreamError(
                f"FMP indisponível: {exc.__class__.__name__}", status_code=502
            ) from exc

        if response.status_code == 404:
            return None
        if response.status_code in (401, 403):
            raise UpstreamError("FMP API key inválida", status_code=response.status_code)
        if response.status_code == 429:
            raise UpstreamError("FMP limite de requisições atingido", status_code=429)
        if response.status_code >= 400:
            raise UpstreamError(f"FMP erro {response.status_code}", status_code=502)

        try:
            payload = response.json()
        except ValueError:
            return None

        if isinstance(payload, list):
            first = payload[0] if payload else None
            return first if isinstance(first, dict) and first.get("symbol") else None
        if isinstance(payload, dict) and payload.get("symbol"):
            return payload
        return None


fmp_client = FmpClient()
