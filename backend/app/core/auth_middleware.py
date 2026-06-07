from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse

from app.config import settings
from app.core.exceptions import AppError
from app.core.jwt_auth import auth_is_enabled, decode_access_token

_BASE_PUBLIC_PATHS = {
    "/health",
    "/v1/auth/register",
    "/v1/auth/login",
    "/v1/auth/anonymous",
}

_DOC_PUBLIC_PATHS = {"/docs", "/openapi.json", "/redoc"}


class AuthMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        # Browsers (Flutter web) enviam OPTIONS antes de GET/POST com Authorization.
        if request.method == "OPTIONS":
            return await call_next(request)

        if not auth_is_enabled() or self._is_public(request.url.path):
            return await call_next(request)

        header = request.headers.get("Authorization", "")
        if not header.startswith("Bearer "):
            return JSONResponse(status_code=401, content={"detail": "Não autenticado"})

        token = header.removeprefix("Bearer ").strip()
        if not token:
            return JSONResponse(status_code=401, content={"detail": "Não autenticado"})

        try:
            request.state.auth_user = decode_access_token(token)
        except AppError as exc:
            return JSONResponse(status_code=exc.status_code, content={"detail": exc.message})

        return await call_next(request)

    @staticmethod
    def _is_public(path: str) -> bool:
        public_paths = set(_BASE_PUBLIC_PATHS)
        if settings.docs_enabled:
            public_paths.update(_DOC_PUBLIC_PATHS)
        if path in public_paths:
            return True
        # Logos são assets cacheáveis — não exigem JWT (Image.network não envia Bearer).
        if path.endswith("/logo.png"):
            return True
        return False
