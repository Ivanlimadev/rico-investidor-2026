"""Vincula Open Finance ao usuário autenticado (JWT sub) — evita IDOR por client_user_id."""

from fastapi import Request

from app.core.exceptions import AppError
from app.core.jwt_auth import auth_is_enabled


def open_finance_client_id_for_user(user_id: str) -> str:
    safe = user_id.strip()
    if not safe:
        raise AppError("Usuário inválido", status_code=401)
    return f"rico-user-{safe}"


def resolve_open_finance_client_id(request: Request) -> str:
    if not auth_is_enabled():
        raise AppError(
            "Open Finance exige autenticação (configure AUTH_SECRET)",
            status_code=503,
        )

    auth_user = getattr(request.state, "auth_user", None)
    if auth_user is None:
        raise AppError("Não autenticado", status_code=401)

    return open_finance_client_id_for_user(auth_user.id)
