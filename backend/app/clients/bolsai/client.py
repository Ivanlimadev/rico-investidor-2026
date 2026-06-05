from __future__ import annotations

import httpx

from app.clients.bolsai.models import BolsaiDividendsResponse
from app.config import settings
from app.core.exceptions import UpstreamError
from app.core.http_client import get_http_client
from app.core.upstream_errors import log_upstream_failure, upstream_public_message


class BolsaiClient:
    """Cliente Bolsai — proventos, fundamentos TTM, histórico, FIIs e macro BCB."""

    def __init__(self, *, api_key: str | None = None, base_url: str | None = None) -> None:
        self._api_key = (api_key if api_key is not None else settings.bolsai_api_key).strip()
        self._base_url = (base_url or settings.bolsai_base_url).rstrip("/")

    @property
    def configured(self) -> bool:
        return bool(self._api_key)

    def _headers(self) -> dict[str, str]:
        return {"X-API-Key": self._api_key}

    async def _get(self, path: str, *, params: dict | None = None) -> dict:
        url = f"{self._base_url}/{path.lstrip('/')}"
        try:
            client = get_http_client()
            response = await client.get(
                url,
                headers=self._headers(),
                params=params or {},
                timeout=25.0,
            )
        except httpx.RequestError as exc:
            raise UpstreamError(
                f"Bolsai indisponível: {exc.__class__.__name__}",
                status_code=502,
            ) from exc

        if response.status_code == 404:
            raise UpstreamError("Ativo não encontrado na Bolsai", status_code=404)
        if response.status_code == 429:
            raise UpstreamError("Limite diário da Bolsai excedido", status_code=429)
        if response.status_code in (401, 403):
            raise UpstreamError("Bolsai API key inválida", status_code=response.status_code)
        if response.status_code >= 400:
            log_upstream_failure(
                provider="Bolsai",
                status=response.status_code,
                url=url,
                body=response.text[:300],
            )
            raise UpstreamError(
                upstream_public_message("Bolsai", response.status_code),
                status_code=502,
            )

        try:
            payload = response.json()
        except ValueError as exc:
            raise UpstreamError("Resposta Bolsai inválida", status_code=502) from exc

        if not isinstance(payload, dict):
            raise UpstreamError("Resposta Bolsai inválida", status_code=502)
        return payload

    async def _get_optional(self, path: str, *, params: dict | None = None) -> dict | None:
        if not self.configured:
            return None
        try:
            return await self._get(path, params=params)
        except UpstreamError as exc:
            if exc.status_code in {404, 429}:
                return None
            raise

    async def get_dividends(self, ticker: str) -> BolsaiDividendsResponse | None:
        """Proventos de ações, BDRs e ETFs listados na B3."""
        return await self._fetch_dividends(f"/dividends/{ticker}")

    async def get_fii_distributions(self, ticker: str) -> BolsaiDividendsResponse | None:
        """Rendimentos e distribuições de FIIs."""
        return await self._fetch_dividends(f"/fiis/{ticker}/distributions")

    async def _fetch_dividends(self, path: str) -> BolsaiDividendsResponse | None:
        normalized_path = path.strip("/")
        if not normalized_path:
            return None
        data = await self._get_optional(f"/{normalized_path}")
        if data is None:
            return None
        return BolsaiDividendsResponse.model_validate(data)

    async def get_fundamentals(self, ticker: str) -> dict | None:
        """27 indicadores TTM para ações B3."""
        normalized = ticker.upper().strip()
        if not normalized:
            return None
        return await self._get_optional(f"/fundamentals/{normalized}")

    async def get_fundamentals_history(
        self,
        ticker: str,
        *,
        limit: int = 12,
    ) -> dict | None:
        normalized = ticker.upper().strip()
        if not normalized:
            return None
        return await self._get_optional(
            f"/fundamentals/{normalized}/history",
            params={"limit": limit} if limit > 0 else None,
        )

    async def get_stock_history(
        self,
        ticker: str,
        *,
        limit: int = 5000,
        start: str | None = None,
        end: str | None = None,
    ) -> dict | None:
        normalized = ticker.upper().strip()
        if not normalized:
            return None
        params: dict[str, str | int] = {}
        if limit > 0:
            params["limit"] = limit
        if start:
            params["start"] = start
        if end:
            params["end"] = end
        return await self._get_optional(f"/stocks/{normalized}/history", params=params or None)

    async def get_corporate_events(self, ticker: str) -> dict | None:
        normalized = ticker.upper().strip()
        if not normalized:
            return None
        return await self._get_optional(f"/stocks/{normalized}/corporate-events")

    async def get_fii(self, ticker: str) -> dict | None:
        normalized = ticker.upper().strip()
        if not normalized:
            return None
        return await self._get_optional(f"/fiis/{normalized}")

    async def get_macro_selic(self) -> dict | None:
        return await self._get_optional("/macro/selic")

    async def get_macro_cdi(self) -> dict | None:
        return await self._get_optional("/macro/cdi")

    async def get_macro_ipca(self) -> dict | None:
        return await self._get_optional("/macro/ipca")

    async def get_stock_quote(self, ticker: str) -> dict | None:
        normalized = ticker.upper().strip()
        if not normalized:
            return None
        return await self._get_optional(f"/stocks/{normalized}/quote")

    async def get_company(self, ticker: str) -> dict | None:
        normalized = ticker.upper().strip()
        if not normalized:
            return None
        return await self._get_optional(f"/companies/{normalized}")

    async def list_fiis(
        self,
        *,
        limit: int = 100,
        offset: int = 0,
    ) -> dict | None:
        return await self._get_optional(
            "/fiis",
            params={"limit": max(1, limit), "offset": max(0, offset)},
        )

    async def get_fii_screener(self, *, params: dict | None = None) -> dict | None:
        return await self._get_optional("/fiis/screener", params=params or {})

    async def get_screener(self, *, params: dict | None = None) -> dict | None:
        return await self._get_optional("/screener", params=params or {})

    async def get_financials(
        self,
        ticker: str,
        *,
        limit: int = 2000,
        period: str = "quarterly",
    ) -> dict | None:
        normalized = ticker.upper().strip()
        if not normalized:
            return None
        report_type = "ITR" if period.strip().lower() in {"quarterly", "quarter", "trimestral"} else "DFP"
        return await self._get_optional(
            f"/financials/{normalized}",
            params={"limit": limit, "report_type": report_type},
        )
