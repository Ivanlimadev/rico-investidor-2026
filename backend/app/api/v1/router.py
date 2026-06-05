from fastapi import APIRouter

from app.api.v1.dividends import router as dividends_router
from app.api.v1.crypto import router as crypto_router
from app.api.v1.currency import router as currency_router
from app.api.v1.global_markets import router as global_markets_router
from app.api.v1.home import router as home_router
from app.api.v1.auth import router as auth_router
from app.api.v1.assets import router as assets_router
from app.api.v1.fiis import router as fiis_router
from app.api.v1.macro import router as macro_router
from app.api.v1.meta import router as meta_router
from app.api.v1.open_finance import router as open_finance_router
from app.api.v1.indices import router as indices_router
from app.api.v1.quotes import router as quotes_router
from app.api.v1.related import router as related_router
from app.api.v1.treasury import router as treasury_router
from app.providers.fii_providers import fii_provider_rules
from app.providers.registry import AssetClass, provider_for

router = APIRouter(prefix="/v1")
router.include_router(home_router)
router.include_router(currency_router)
router.include_router(crypto_router)
router.include_router(global_markets_router)
router.include_router(auth_router)
router.include_router(assets_router)
router.include_router(fiis_router)
router.include_router(macro_router)
router.include_router(meta_router)
router.include_router(quotes_router)
router.include_router(dividends_router)
router.include_router(related_router)
router.include_router(treasury_router)
router.include_router(indices_router)
router.include_router(open_finance_router)


@router.get("/meta/providers")
async def providers_meta():
    return {
        "rules": {
            "stock_br": provider_for(AssetClass.STOCK_BR).value,
            "stock_us": provider_for(AssetClass.STOCK_US).value,
            "etf_br": provider_for(AssetClass.ETF_BR).value,
            "bdr": provider_for(AssetClass.BDR).value,
        },
        "fii": fii_provider_rules(),
        "note": "Brasil: Brapi. EUA e bolsas globais: Marketstack.",
    }
