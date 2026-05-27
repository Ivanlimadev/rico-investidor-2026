from fastapi import APIRouter, Query

from app.services.macro_service import macro_service

router = APIRouter(prefix="/meta", tags=["Meta"])


@router.get("/dictionary")
async def get_dictionary(
    category: str = Query(default="statistics", max_length=32),
):
    """Glossário de campos Brapi — tooltips de indicadores."""
    return await macro_service.get_dictionary(category=category)
