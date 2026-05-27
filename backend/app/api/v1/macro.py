from fastapi import APIRouter

from app.services.macro_service import macro_service

router = APIRouter(prefix="/macro", tags=["Macro (Brapi)"])


@router.get("/brazil")
async def get_brazil_macro():
    """Selic e IPCA 12m — contexto macro para renda variável."""
    return await macro_service.get_brazil_macro()
