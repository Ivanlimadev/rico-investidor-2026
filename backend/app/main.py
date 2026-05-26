from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.v1.router import router as v1_router
from app.core.exceptions import AppError
from app.services.fii_service import fii_service

app = FastAPI(
    title="Rico Investidor API",
    description="Backend API. FIIs: Brapi + Bolsai. Ações BR: Brapi.",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(v1_router)


@app.exception_handler(AppError)
async def app_error_handler(_: Request, exc: AppError) -> JSONResponse:
    return JSONResponse(status_code=exc.status_code, content={"detail": exc.message})


@app.get("/health")
async def health():
    return {
        "status": "ok",
        "fii_providers": fii_service.capability_providers(),
        "quote_provider": "brapi",
    }
