import time
from collections import defaultdict, deque

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse

from app.config import settings

_AUTH_PATH_PREFIX = "/v1/auth/"


class RateLimitMiddleware(BaseHTTPMiddleware):
    """Limite por IP — global para a API; mais rígido em /v1/auth/*."""

    def __init__(
        self,
        app,
        *,
        max_requests: int = 180,
        auth_max_requests: int = 10,
        window_seconds: int = 60,
    ) -> None:
        super().__init__(app)
        self._max_requests = max_requests
        self._auth_max_requests = auth_max_requests
        self._window = window_seconds
        self._hits: dict[str, deque[float]] = defaultdict(deque)
        self._auth_hits: dict[str, deque[float]] = defaultdict(deque)

    def _client_ip(self, request: Request) -> str:
        forwarded = request.headers.get("x-forwarded-for")
        if forwarded:
            return forwarded.split(",")[0].strip()
        if request.client:
            return request.client.host
        return "unknown"

    @staticmethod
    def _trim(bucket: deque[float], now: float, window: float) -> None:
        while bucket and now - bucket[0] > window:
            bucket.popleft()

    def _is_limited(self, bucket: deque[float], limit: int) -> bool:
        return len(bucket) >= limit

    @staticmethod
    def _should_skip_rate_limit(path: str) -> bool:
        if path in {"/health"}:
            return True
        if settings.docs_enabled and path in {"/docs", "/openapi.json", "/redoc"}:
            return True
        # Logos são cacheáveis e o app pré-carrega dezenas em paralelo na abertura.
        if path.endswith("/logo.png"):
            return True
        return False

    async def dispatch(self, request: Request, call_next):
        path = request.url.path
        if self._should_skip_rate_limit(path):
            return await call_next(request)

        ip = self._client_ip(request)
        now = time.monotonic()

        if path.startswith(_AUTH_PATH_PREFIX):
            auth_bucket = self._auth_hits[ip]
            self._trim(auth_bucket, now, self._window)
            if self._is_limited(auth_bucket, self._auth_max_requests):
                return JSONResponse(
                    status_code=429,
                    content={
                        "detail": "Muitas tentativas de autenticação — tente novamente em instantes."
                    },
                )
            auth_bucket.append(now)
        else:
            bucket = self._hits[ip]
            self._trim(bucket, now, self._window)
            if self._is_limited(bucket, self._max_requests):
                return JSONResponse(
                    status_code=429,
                    content={"detail": "Muitas requisições — tente novamente em instantes."},
                )
            bucket.append(now)

        return await call_next(request)
