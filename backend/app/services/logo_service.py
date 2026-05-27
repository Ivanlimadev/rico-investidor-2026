import httpx

from app.clients.brapi.stock_mapper import b3_icon_png_url
from app.core.cache import TtlCache
from app.core.exceptions import UpstreamError
from app.core.http_client import get_http_client

_LOGO_CACHE_TTL = 60 * 60 * 24


class LogoService:
    """Proxy de logos PNG — evita SVG quebrado e URLs externas no app."""

    def __init__(self) -> None:
        self._cache: TtlCache[bytes] = TtlCache(_LOGO_CACHE_TTL)

    async def get_png(self, ticker: str) -> bytes:
        normalized = ticker.upper().strip()
        if not normalized:
            raise UpstreamError("Ticker inválido", status_code=400)

        cached = self._cache.get(normalized)
        if cached is not None:
            return cached

        url = b3_icon_png_url(normalized)
        try:
            client = get_http_client()
            response = await client.get(url, timeout=15.0)
        except httpx.RequestError as exc:
            raise UpstreamError(
                f"Falha ao baixar logo: {exc.__class__.__name__}",
                status_code=502,
            ) from exc

        if response.status_code == 404:
            raise UpstreamError(f"Logo não encontrado: {normalized}", status_code=404)
        if response.status_code >= 400:
            raise UpstreamError(
                f"Erro ao baixar logo ({response.status_code})",
                status_code=502,
            )

        content = response.content
        if len(content) < 64:
            raise UpstreamError(f"Logo inválido: {normalized}", status_code=502)

        self._cache.set(normalized, content)
        return content


logo_service = LogoService()
