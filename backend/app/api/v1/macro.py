from fastapi import APIRouter

from app.services.macro_service import macro_service

router = APIRouter(prefix="/macro", tags=["Macro"])


@router.get("/brazil")
async def get_brazil_macro():
    """Selic, IPCA 12m e CDI — BCB via Bolsai (híbrido com Brapi)."""
    return await macro_service.get_brazil_macro()
