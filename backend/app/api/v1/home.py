from fastapi import APIRouter

from app.domain.home.models import HomeFeedResponse
from app.services.home_service import home_service

router = APIRouter(prefix="/home", tags=["Home"])


@router.get("/feed", response_model=HomeFeedResponse)
async def home_feed():
    """Agrega dados da home: destaques, contagens de mercado e macro."""
    return await home_service.get_feed()
