from fastapi import APIRouter, Depends, File, Request, UploadFile

from app.domain.auth.models import (
    AnonymousAuthRequest,
    ChangePasswordRequest,
    DeleteAccountRequest,
    ForgotPasswordRequest,
    LoginRequest,
    MessageResponse,
    RegisterRequest,
    ResetPasswordRequest,
    TokenResponse,
    UpdateProfileRequest,
    UserResponse,
)
from app.core.auth_deps import get_auth_user
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
    auth_user = get_auth_user(request)
    return service.me(auth_user.id)


@router.patch("/me", response_model=UserResponse)
async def update_me(
    body: UpdateProfileRequest,
    request: Request,
    service: AuthService = Depends(get_auth_service),
):
    auth_user = get_auth_user(request)
    return service.update_profile(auth_user.id, name=body.name)


@router.post("/me/photo", response_model=UserResponse)
async def upload_me_photo(
    request: Request,
    file: UploadFile = File(...),
    service: AuthService = Depends(get_auth_service),
):
    auth_user = get_auth_user(request)
    content = await file.read()
    return service.upload_photo(
        auth_user.id,
        content=content,
        content_type=file.content_type or "",
    )


@router.post("/forgot-password", response_model=MessageResponse)
async def forgot_password(
    body: ForgotPasswordRequest,
    service: AuthService = Depends(get_auth_service),
):
    return service.forgot_password(email=body.email)


@router.post("/reset-password", response_model=MessageResponse)
async def reset_password(
    body: ResetPasswordRequest,
    service: AuthService = Depends(get_auth_service),
):
    return service.reset_password(token=body.token, new_password=body.new_password)


@router.post("/change-password", response_model=MessageResponse)
async def change_password(
    body: ChangePasswordRequest,
    request: Request,
    service: AuthService = Depends(get_auth_service),
):
    auth_user = get_auth_user(request)
    return service.change_password(
        auth_user.id,
        current_password=body.current_password,
        new_password=body.new_password,
    )


@router.delete("/me", response_model=MessageResponse)
async def delete_me(
    body: DeleteAccountRequest,
    request: Request,
    service: AuthService = Depends(get_auth_service),
):
    auth_user = get_auth_user(request)
    return service.delete_account(auth_user.id, password=body.password)
