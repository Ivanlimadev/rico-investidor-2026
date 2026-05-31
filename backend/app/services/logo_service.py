import httpx

from app.clients.binance.crypto_mapper import crypto_logo_source_urls
from app.clients.brapi.stock_mapper import b3_logo_source_urls
from app.clients.marketstack.stock_mapper import us_logo_source_url
from app.config import settings
from app.core.cache import TtlCache
from app.core.disk_cache import DiskBytesCache, NegativeCache
from app.core.exceptions import UpstreamError
from app.core.http_client import get_http_client


class LogoService:
    """Proxy de logos PNG — evita SVG quebrado e URLs externas no app.

    Camadas de cache (da mais rápida à origem):
      1. Memória (TTL curto/médio) — resposta instantânea.
      2. Disco (TTL longo) — persiste entre reinícios; logos quase nunca mudam.
      3. Cache negativo — símbolos sem logo não são re-baixados por um período,
         protegendo as APIs gratuitas de origem (FMP/icones-b3).
    """

    def __init__(self) -> None:
        self._memory: TtlCache[bytes] = TtlCache(
            settings.logo_memory_cache_ttl_seconds,
            max_entries=settings.logo_memory_max_entries,
        )
        self._disk = DiskBytesCache(
            settings.logo_cache_dir,
            ttl_seconds=settings.logo_disk_cache_ttl_seconds,
        )
        self._negative = NegativeCache(settings.logo_negative_cache_ttl_seconds)

    async def _get(self, cache_key: str, source_url: str, *, label: str) -> bytes:
        cached = self._memory.get(cache_key)
        if cached is not None:
            return cached

        on_disk = self._disk.get(cache_key)
        if on_disk is not None:
            self._memory.set(cache_key, on_disk)
            return on_disk

        if self._negative.is_blocked(cache_key):
            raise UpstreamError(f"Logo não encontrado: {label}", status_code=404)

        try:
            client = get_http_client()
            response = await client.get(source_url, timeout=15.0)
        except httpx.RequestError as exc:
            # Erro transitório — não envenena o cache negativo.
            raise UpstreamError(
                f"Falha ao baixar logo: {exc.__class__.__name__}",
                status_code=502,
            ) from exc

        if response.status_code == 404:
            self._negative.mark(cache_key)
            raise UpstreamError(f"Logo não encontrado: {label}", status_code=404)
        if response.status_code >= 400:
            raise UpstreamError(
                f"Erro ao baixar logo ({response.status_code})",
                status_code=502,
            )

        content = response.content
        if len(content) < 64:
            # Resposta inválida/placeholder — trata como ausência.
            self._negative.mark(cache_key)
            raise UpstreamError(f"Logo inválido: {label}", status_code=404)

        self._memory.set(cache_key, content)
        self._disk.set(cache_key, content)
        return content

    async def _get_multi(
        self, cache_key: str, source_urls: list[str], *, label: str
    ) -> bytes:
        """Igual a `_get`, mas tenta múltiplas origens em ordem.

        Só envenena o cache negativo quando TODAS as origens responderam 404/
        inválido; erros transitórios (rede) viram 502 sem bloquear o símbolo.
        """
        cached = self._memory.get(cache_key)
        if cached is not None:
            return cached

        on_disk = self._disk.get(cache_key)
        if on_disk is not None:
            self._memory.set(cache_key, on_disk)
            return on_disk

        if self._negative.is_blocked(cache_key):
            raise UpstreamError(f"Logo não encontrado: {label}", status_code=404)

        client = get_http_client()
        transient_error: Exception | None = None

        for source_url in source_urls:
            try:
                response = await client.get(source_url, timeout=15.0)
            except httpx.RequestError as exc:
                transient_error = exc
                continue

            if response.status_code >= 400:
                continue

            content = response.content
            if len(content) < 64:
                continue

            self._memory.set(cache_key, content)
            self._disk.set(cache_key, content)
            return content

        if transient_error is not None:
            raise UpstreamError(
                f"Falha ao baixar logo: {transient_error.__class__.__name__}",
                status_code=502,
            ) from transient_error

        self._negative.mark(cache_key)
        raise UpstreamError(f"Logo não encontrado: {label}", status_code=404)

    async def get_png(self, ticker: str) -> bytes:
        normalized = ticker.upper().strip()
        if not normalized:
            raise UpstreamError("Ticker inválido", status_code=400)
        return await self._get_multi(
            normalized,
            b3_logo_source_urls(normalized),
            label=normalized,
        )

    async def get_us_png(self, symbol: str) -> bytes:
        normalized = symbol.upper().strip()
        if not normalized:
            raise UpstreamError("Ticker inválido", status_code=400)
        return await self._get(f"us:{normalized}", us_logo_source_url(normalized), label=normalized)

    async def get_crypto_png(self, symbol: str) -> bytes:
        normalized = symbol.upper().strip()
        if not normalized:
            raise UpstreamError("Ticker inválido", status_code=400)
        return await self._get_multi(
            f"crypto:{normalized}",
            crypto_logo_source_urls(normalized),
            label=normalized,
        )


logo_service = LogoService()
