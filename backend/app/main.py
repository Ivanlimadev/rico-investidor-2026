import asyncio
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.v1.router import router as v1_router
from app.config import settings
from app.core.auth_middleware import AuthMiddleware
from app.core.exceptions import AppError
from app.core.http_client import close_http_client
from app.core.cors_config import build_cors_origin_regex
from app.core.production_guard import validate_production_settings
from app.core.rate_limit import RateLimitMiddleware
from app.core.security_headers import SecurityHeadersMiddleware
from app.db.init_db import init_database


@asynccontextmanager
async def lifespan(_: FastAPI):
    validate_production_settings()
    init_database()
    yield
    await close_http_client()


def create_app(*, docs_enabled: bool | None = None) -> FastAPI:
    """Factory para permitir testes com docs ligadas/desligadas."""
    show_docs = settings.docs_enabled if docs_enabled is None else docs_enabled
    docs_url = "/docs" if show_docs else None
    redoc_url = "/redoc" if show_docs else None
    openapi_url = "/openapi.json" if show_docs else None

    application = FastAPI(
        title="Rico Investidor API",
        description="Backend API — mercado americano (Marketstack) e cripto.",
        version="0.1.0",
        lifespan=lifespan,
        docs_url=docs_url,
        redoc_url=redoc_url,
        openapi_url=openapi_url,
    )

    application.add_middleware(SecurityHeadersMiddleware)
    application.add_middleware(
        RateLimitMiddleware,
        max_requests=settings.rate_limit_per_minute,
        auth_max_requests=settings.auth_rate_limit_per_minute,
        logo_max_requests=settings.logo_rate_limit_per_minute,
        trust_proxy_headers=settings.trust_proxy_headers,
        window_seconds=60,
    )
    application.add_middleware(
        CORSMiddleware,
        allow_origin_regex=build_cors_origin_regex(),
        allow_credentials=False,
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type", "X-Open-Finance-Key"],
    )
    application.add_middleware(AuthMiddleware)

    application.include_router(v1_router)

    @application.exception_handler(AppError)
    async def app_error_handler(_: Request, exc: AppError) -> JSONResponse:
        return JSONResponse(status_code=exc.status_code, content={"detail": exc.message})

    @application.get("/health")
    async def health():
        return {
            "status": "ok",
            "markets": ["US", "crypto"],
            "quote_provider": "marketstack",
        }

    return application


app = create_app()
