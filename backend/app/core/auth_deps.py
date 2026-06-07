from fastapi import Request

from app.core.exceptions import AppError
from app.core.jwt_auth import AuthUser
from app.services.user_store import StoredUser, UserStore


def get_auth_user(request: Request) -> AuthUser:
    auth_user = getattr(request.state, "auth_user", None)
    if auth_user is None:
        raise AppError("Não autenticado", status_code=401)
    return auth_user


def require_registered_user(request: Request) -> StoredUser:
    auth_user = get_auth_user(request)
    user = UserStore().get_by_id(auth_user.id)
    if user is None:
        raise AppError("Usuário não encontrado", status_code=404)
    if user.is_anonymous:
        raise AppError("Conta registrada necessária", status_code=403)
    return user
