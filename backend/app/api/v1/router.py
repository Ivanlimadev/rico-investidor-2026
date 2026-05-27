from fastapi import APIRouter

from app.api.v1.assets import router as assets_router
from app.api.v1.fiis import router as fiis_router
from app.api.v1.macro import router as macro_router
from app.api.v1.meta import router as meta_router
from app.api.v1.open_finance import router as open_finance_router
from app.api.v1.quotes import router as quotes_router
from app.providers.fii_providers import fii_provider_rules
from app.providers.registry import AssetClass, provider_for

router = APIRouter(prefix="/v1")
router.include_router(assets_router)
router.include_router(fiis_router)
router.include_router(macro_router)
router.include_router(meta_router)
router.include_router(quotes_router)
router.include_router(open_finance_router)


@router.get("/meta/providers")
async def providers_meta():
    return {
        "rules": {
            "stock_br": provider_for(AssetClass.STOCK_BR).value,
            "etf_br": provider_for(AssetClass.ETF_BR).value,
            "bdr": provider_for(AssetClass.BDR).value,
        },
        "fii": fii_provider_rules(),
        "note": "FIIs: Brapi (core) + Bolsai (imóveis, inquilinos, screener). Ações/BDRs/ETFs: Brapi.",
    }
