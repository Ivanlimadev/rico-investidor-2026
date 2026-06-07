from fastapi import APIRouter

from app.api.v1.dividends import router as dividends_router
from app.api.v1.crypto import router as crypto_router
from app.api.v1.global_markets import router as global_markets_router
from app.api.v1.home import router as home_router
from app.api.v1.auth import router as auth_router
from app.api.v1.meta import router as meta_router
from app.api.v1.open_finance import router as open_finance_router
from app.api.v1.portfolio import router as portfolio_router
from app.api.v1.related import router as related_router
from app.providers.registry import AssetClass, provider_for

router = APIRouter(prefix="/v1")
router.include_router(home_router)
router.include_router(crypto_router)
router.include_router(global_markets_router)
router.include_router(auth_router)
router.include_router(meta_router)
router.include_router(dividends_router)
router.include_router(related_router)
router.include_router(open_finance_router)
router.include_router(portfolio_router)


@router.get("/meta/providers")
async def providers_meta():
    return {
        "rules": {
            "stock_us": provider_for(AssetClass.STOCK_US).value,
        },
        "note": "Mercado americano: Marketstack. Cripto: CoinCap/Binance.",
    }
