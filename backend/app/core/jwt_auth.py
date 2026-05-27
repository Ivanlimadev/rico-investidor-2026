from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

import jwt

from app.config import settings
from app.core.exceptions import AppError


@dataclass(frozen=True)
class AuthUser:
    id: str
    email: str


def auth_is_enabled() -> bool:
    return bool(settings.auth_secret.strip())


def create_access_token(user_id: str, email: str) -> tuple[str, int]:
    if not auth_is_enabled():
        raise AppError("AUTH_SECRET não configurado", status_code=503)

    expires_in = settings.auth_token_ttl_seconds
    payload = {
        "sub": user_id,
        "email": email,
        "exp": datetime.now(UTC) + timedelta(seconds=expires_in),
        "iat": datetime.now(UTC),
    }
    token = jwt.encode(payload, settings.auth_secret, algorithm="HS256")
    return token, expires_in


def decode_access_token(token: str) -> AuthUser:
    if not auth_is_enabled():
        raise AppError("AUTH_SECRET não configurado", status_code=503)

    try:
        payload = jwt.decode(token, settings.auth_secret, algorithms=["HS256"])
    except jwt.ExpiredSignatureError as exc:
        raise AppError("Token expirado", status_code=401) from exc
    except jwt.InvalidTokenError as exc:
        raise AppError("Token inválido", status_code=401) from exc

    user_id = payload.get("sub")
    email = payload.get("email")
    if not user_id or not email:
        raise AppError("Token inválido", status_code=401)

    return AuthUser(id=str(user_id), email=str(email))
