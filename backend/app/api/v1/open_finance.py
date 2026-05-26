from pydantic import BaseModel, Field

from fastapi import APIRouter

from app.services.open_finance_service import OpenFinanceService

router = APIRouter(prefix="/open-finance", tags=["Open Finance (Pluggy)"])
_service = OpenFinanceService()


class ConnectTokenRequest(BaseModel):
    client_user_id: str = Field(min_length=3, max_length=128)


class ConnectTokenResponse(BaseModel):
    connect_token: str
    provider: str = "pluggy"


class RegisterItemRequest(BaseModel):
    client_user_id: str = Field(min_length=3, max_length=128)
    item_id: str = Field(min_length=8, max_length=64)


class RegisterItemResponse(BaseModel):
    ok: bool = True
    linked_items: int
    provider: str = "pluggy"


@router.post("/connect-token", response_model=ConnectTokenResponse)
async def create_connect_token(body: ConnectTokenRequest):
    """Token para abrir o widget Pluggy Connect no app."""
    token = await _service.create_connect_token(body.client_user_id)
    return ConnectTokenResponse(connect_token=token)


@router.post("/items", response_model=RegisterItemResponse)
async def register_item(body: RegisterItemRequest):
    """Registra item conectado pelo widget (callback onSuccess)."""
    _service.register_item(body.client_user_id, body.item_id)
    status = _service.status(body.client_user_id)
    return RegisterItemResponse(linked_items=status["linked_items"])


@router.get("/status")
async def open_finance_status(client_user_id: str):
    return _service.status(client_user_id)


@router.post("/sync")
async def sync_portfolio(body: ConnectTokenRequest):
    """Importa investimentos Open Finance como carteira consolidada."""
    return await _service.sync_portfolio(body.client_user_id)
