from fastapi import APIRouter

from app.config import settings
from app.core.cached_json import cached_json_response
from app.services.home_service import home_service

router = APIRouter(prefix="/home", tags=["Home"])


@router.get("/feed")
async def home_feed():
    """Agrega dados da home: destaques US, cripto e contagens de mercado."""
    payload = await home_service.get_feed()
    return cached_json_response(payload, max_age_seconds=settings.quote_cache_ttl_seconds)
