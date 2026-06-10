from fastapi import APIRouter, Depends, Request

from app.core.auth_deps import require_registered_user
from app.domain.alerts.models import (
    PriceAlertCreateRequest,
    PriceAlertListResponse,
    PriceAlertResponse,
)
from app.domain.auth.models import MessageResponse
from app.services.alert_service import AlertService, alert_service

router = APIRouter(prefix="/alerts", tags=["Alertas"])


def get_alert_service() -> AlertService:
    return alert_service


@router.get("", response_model=PriceAlertListResponse)
async def list_alerts(
    request: Request,
    service: AlertService = Depends(get_alert_service),
):
    user = require_registered_user(request)
    return service.list_alerts(user.id)


@router.post("", response_model=PriceAlertResponse)
async def create_alert(
    body: PriceAlertCreateRequest,
    request: Request,
    service: AlertService = Depends(get_alert_service),
):
    user = require_registered_user(request)
    return service.create_alert(user.id, body)


@router.delete("/{alert_id}", response_model=MessageResponse)
async def delete_alert(
    alert_id: str,
    request: Request,
    service: AlertService = Depends(get_alert_service),
):
    user = require_registered_user(request)
    return service.delete_alert(user.id, alert_id)
