from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.v1.router import router as v1_router
from app.config import settings
from app.core.auth_middleware import AuthMiddleware
from app.core.exceptions import AppError
from app.core.http_client import close_http_client
from app.core.rate_limit import RateLimitMiddleware
from app.services.fii_service import fii_service


def _parse_cors_origins(raw: str) -> list[str]:
    origins = [part.strip() for part in raw.split(",") if part.strip()]
    return origins or ["http://127.0.0.1:3000", "http://localhost:3000"]


@asynccontextmanager
async def lifespan(_: FastAPI):
    yield
    await close_http_client()


app = FastAPI(
    title="Rico Investidor API",
    description="Backend API. FIIs e ações BR: Brapi.",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    RateLimitMiddleware,
    max_requests=settings.rate_limit_per_minute,
    window_seconds=60,
)
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)
app.add_middleware(AuthMiddleware)

app.include_router(v1_router)


@app.exception_handler(AppError)
async def app_error_handler(_: Request, exc: AppError) -> JSONResponse:
    return JSONResponse(status_code=exc.status_code, content={"detail": exc.message})


@app.get("/health")
async def health():
    return {"status": "ok", "quote_provider": "brapi", "fii_provider": "brapi"}
