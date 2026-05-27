import time
from collections import defaultdict, deque

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse


class RateLimitMiddleware(BaseHTTPMiddleware):
    """Limite simples por IP — protege contra abuso de screener/catalog."""

    def __init__(self, app, *, max_requests: int = 180, window_seconds: int = 60) -> None:
        super().__init__(app)
        self._max_requests = max_requests
        self._window = window_seconds
        self._hits: dict[str, deque[float]] = defaultdict(deque)

    def _client_ip(self, request: Request) -> str:
        forwarded = request.headers.get("x-forwarded-for")
        if forwarded:
            return forwarded.split(",")[0].strip()
        if request.client:
            return request.client.host
        return "unknown"

    async def dispatch(self, request: Request, call_next):
        if request.url.path in {"/health", "/docs", "/openapi.json", "/redoc"}:
            return await call_next(request)

        ip = self._client_ip(request)
        now = time.monotonic()
        bucket = self._hits[ip]

        while bucket and now - bucket[0] > self._window:
            bucket.popleft()

        if len(bucket) >= self._max_requests:
            return JSONResponse(
                status_code=429,
                content={"detail": "Muitas requisições — tente novamente em instantes."},
            )

        bucket.append(now)
        return await call_next(request)
