import hashlib
import secrets

from app.core.exceptions import AppError
from app.core.jwt_auth import create_access_token
from app.domain.auth.models import TokenResponse, UserResponse
from app.services.user_store import StoredUser, UserStore


def hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt.encode("utf-8"),
        120_000,
    )
    return f"{salt}${digest.hex()}"


def verify_password(password: str, stored_hash: str) -> bool:
    try:
        salt, expected = stored_hash.split("$", 1)
    except ValueError:
        return False
    digest = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt.encode("utf-8"),
        120_000,
    )
    return secrets.compare_digest(digest.hex(), expected)


class AuthService:
    def __init__(self, store: UserStore | None = None) -> None:
        self._store = store or UserStore()

    def register(self, *, email: str, password: str, name: str) -> TokenResponse:
        user = self._store.create_user(
            email=email,
            name=name,
            password_hash=hash_password(password),
        )
        return self._token_for(user)

    def login(self, *, email: str, password: str) -> TokenResponse:
        user = self._store.get_by_email(email)
        if user is None or not verify_password(password, user.password_hash):
            raise AppError("E-mail ou senha inválidos", status_code=401)
        return self._token_for(user)

    def anonymous(self, *, device_id: str) -> TokenResponse:
        user = self._store.get_or_create_device_user(device_id)
        return self._token_for(user)

    def me(self, user_id: str) -> UserResponse:
        user = self._store.get_by_id(user_id)
        if user is None:
            raise AppError("Usuário não encontrado", status_code=404)
        return self._to_response(user)

    def _token_for(self, user: StoredUser) -> TokenResponse:
        token, expires_in = create_access_token(user.id, user.email)
        return TokenResponse(access_token=token, expires_in=expires_in)

    @staticmethod
    def _to_response(user: StoredUser) -> UserResponse:
        return UserResponse(
            id=user.id,
            email=user.email,
            name=user.name,
            is_anonymous=user.is_anonymous,
        )
