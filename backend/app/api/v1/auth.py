from fastapi import APIRouter, Depends, Request

from app.core.exceptions import AppError
from app.domain.auth.models import (
    AnonymousAuthRequest,
    LoginRequest,
    RegisterRequest,
    TokenResponse,
    UserResponse,
)
from app.services.auth_service import AuthService

router = APIRouter(prefix="/auth", tags=["Autenticação"])


def get_auth_service() -> AuthService:
    return AuthService()


@router.post("/register", response_model=TokenResponse)
async def register(body: RegisterRequest, service: AuthService = Depends(get_auth_service)):
    return service.register(email=body.email, password=body.password, name=body.name)


@router.post("/login", response_model=TokenResponse)
async def login(body: LoginRequest, service: AuthService = Depends(get_auth_service)):
    return service.login(email=body.email, password=body.password)


@router.post("/anonymous", response_model=TokenResponse)
async def anonymous(body: AnonymousAuthRequest, service: AuthService = Depends(get_auth_service)):
    """Emite JWT para o app mobile com base no device_id (sem login manual)."""
    return service.anonymous(device_id=body.device_id)


@router.get("/me", response_model=UserResponse)
async def me(request: Request, service: AuthService = Depends(get_auth_service)):
    auth_user = getattr(request.state, "auth_user", None)
    if auth_user is None:
        raise AppError("Não autenticado", status_code=401)
    return service.me(auth_user.id)
