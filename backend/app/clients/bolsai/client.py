import httpx

from app.clients.bolsai.models import (
    FiiCandlesResponse,
    FiiCandleBar,
    FiiDetail,
    FiiDistributions,
    FiiHistoryResponse,
    FiiListResponse,
    FiiScreenerResponse,
    FiiTenantsResponse,
)
from app.config import settings
from app.core.exceptions import NotConfiguredError, UpstreamError
from app.domain.fii.ticker import normalize_fii_ticker


class BolsaiClient:
    """Cliente HTTP da Bolsai — usado exclusivamente para FIIs neste projeto."""

    def __init__(self, api_key: str | None = None, base_url: str | None = None) -> None:
        self._api_key = api_key if api_key is not None else settings.bolsai_api_key
        self._base_url = (base_url or settings.bolsai_base_url).rstrip("/")

    def _headers(self) -> dict[str, str]:
        if not self._api_key:
            raise NotConfiguredError(
                "BOLSAI_API_KEY não configurada. Defina em ~/Secrets/ricoapp1/.env"
            )
        return {"X-API-Key": self._api_key}

    async def _get(self, path: str, params: dict | None = None) -> dict:
        url = f"{self._base_url}/{path.lstrip('/')}"
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.get(url, headers=self._headers(), params=params)
        except httpx.RequestError as exc:
            raise UpstreamError(
                f"Falha ao conectar na Bolsai: {exc.__class__.__name__}",
                status_code=502,
            ) from exc

        if response.status_code == 404:
            raise UpstreamError("FII não encontrado", status_code=404)
        if response.status_code == 429:
            raise UpstreamError("Limite diário da Bolsai excedido", status_code=429)
        if response.status_code >= 400:
            raise UpstreamError(
                f"Erro Bolsai ({response.status_code}): {response.text[:200]}",
                status_code=502,
            )

        return response.json()

    async def list_fiis(self, *, limit: int = 500, offset: int = 0) -> FiiListResponse:
        data = await self._get("/fiis/", params={"limit": limit, "offset": offset})
        return FiiListResponse.model_validate(data)

    async def get_fii(self, ticker: str) -> FiiDetail:
        normalized = normalize_fii_ticker(ticker)
        data = await self._get(f"/fiis/{normalized}")
        return FiiDetail.model_validate(data)

    async def get_fii_distributions(
        self,
        ticker: str,
        *,
        years: int = 5,
    ) -> FiiDistributions:
        normalized = normalize_fii_ticker(ticker)
        data = await self._get(
            f"/fiis/{normalized}/distributions",
            params={"years": years},
        )
        return FiiDistributions.model_validate(data)

    async def get_fii_history(
        self,
        ticker: str,
        *,
        limit: int = 24,
    ) -> FiiHistoryResponse:
        normalized = normalize_fii_ticker(ticker)
        data = await self._get(
            f"/fiis/{normalized}/history",
            params={"limit": limit},
        )
        return FiiHistoryResponse.model_validate(data)

    async def get_stock_candles(
        self,
        ticker: str,
        *,
        limit: int = 252,
        start: str | None = None,
        end: str | None = None,
    ) -> FiiCandlesResponse:
        normalized = normalize_fii_ticker(ticker)
        params: dict[str, str | int] = {"limit": limit}
        if start:
            params["start"] = start
        if end:
            params["end"] = end

        data = await self._get(f"/stocks/{normalized}/history", params=params)
        prices = data.get("prices") or []
        candles = [
            FiiCandleBar(
                trade_date=item["trade_date"],
                open=item["open"],
                high=item["high"],
                low=item["low"],
                close=item["close"],
                volume=item.get("volume"),
            )
            for item in prices
            if item.get("trade_date")
            and item.get("open") is not None
            and item.get("high") is not None
            and item.get("low") is not None
            and item.get("close") is not None
        ]
        return FiiCandlesResponse(
            ticker=data.get("ticker", normalized),
            count=len(candles),
            candles=candles,
        )

    async def get_fii_tenants(self, ticker: str) -> FiiTenantsResponse:
        normalized = normalize_fii_ticker(ticker)
        data = await self._get(f"/fiis/{normalized}/tenants")
        return FiiTenantsResponse.model_validate(data)

    async def screen_fiis(self, params: dict[str, str]) -> FiiScreenerResponse:
        data = await self._get("/fiis/screener", params=params or None)
        return FiiScreenerResponse.model_validate(data)
