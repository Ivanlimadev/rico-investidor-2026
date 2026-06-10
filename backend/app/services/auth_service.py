import hashlib
import secrets
from pathlib import Path

from app.core.exceptions import AppError
from app.core.jwt_auth import create_access_token
from app.config import settings
from app.domain.auth.models import MessageResponse, TokenResponse, UserResponse
from app.services.email_service import EmailService
from app.services.alert_service import AlertService, alert_service
from app.services.finance_service import FinanceService, finance_service
from app.services.password_reset_store import PasswordResetStore
from app.services.user_store import StoredUser, UserStore

_AVATARS_DIR = Path(__file__).resolve().parent.parent / "data" / "avatars"
_MAX_PHOTO_BYTES = 2 * 1024 * 1024
_ALLOWED_PHOTO_TYPES = {"image/jpeg", "image/png"}


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
    def __init__(
        self,
        store: UserStore | None = None,
        reset_store: PasswordResetStore | None = None,
        email_service: EmailService | None = None,
        finance: FinanceService | None = None,
        alerts: AlertService | None = None,
    ) -> None:
        self._store = store or UserStore()
        self._reset_store = reset_store or PasswordResetStore()
        self._email = email_service or EmailService()
        self._finance = finance or finance_service
        self._alerts = alerts or alert_service

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

    def update_profile(self, user_id: str, *, name: str) -> UserResponse:
        user = self._store.update_name(user_id, name)
        return self._to_response(user)

    def upload_photo(self, user_id: str, *, content: bytes, content_type: str) -> UserResponse:
        if len(content) > _MAX_PHOTO_BYTES:
            raise AppError("A foto deve ter no máximo 2 MB", status_code=400)

        normalized_type = (content_type or "").split(";", 1)[0].strip().lower()
        if normalized_type not in _ALLOWED_PHOTO_TYPES:
            raise AppError("Formato inválido. Use JPEG ou PNG.", status_code=400)

        if not _is_jpeg(content) and not _is_png(content):
            raise AppError("Formato inválido. Use JPEG ou PNG.", status_code=400)

        _AVATARS_DIR.mkdir(parents=True, exist_ok=True)
        destination = _AVATARS_DIR / f"{user_id}.jpg"
        destination.write_bytes(content)

        photo_url = f"/static/avatars/{user_id}.jpg"
        user = self._store.update_photo_url(user_id, photo_url)
        return self._to_response(user)

    def forgot_password(self, *, email: str) -> MessageResponse:
        user = self._store.get_by_email(email)
        if user is None or user.is_anonymous or user.email.endswith("@rico.local"):
            return MessageResponse(
                message="If an account exists for this email, you will receive reset instructions shortly."
            )

        raw_token = self._reset_store.create_token(user.id)
        reset_url = f"{settings.app_public_url.rstrip('/')}/reset-password?token={raw_token}"
        self._email.send_password_reset(to_email=user.email, reset_url=reset_url)
        return MessageResponse(
            message="If an account exists for this email, you will receive reset instructions shortly."
        )

    def reset_password(self, *, token: str, new_password: str) -> MessageResponse:
        user_id = self._reset_store.consume_token(token)
        self._store.update_password(user_id, hash_password(new_password))
        return MessageResponse(message="Password updated successfully. You can sign in now.")

    def change_password(
        self,
        user_id: str,
        *,
        current_password: str,
        new_password: str,
    ) -> MessageResponse:
        user = self._store.get_by_id(user_id)
        if user is None:
            raise AppError("Usuário não encontrado", status_code=404)
        if user.is_anonymous:
            raise AppError("Conta anônima não pode alterar senha", status_code=400)
        if not verify_password(current_password, user.password_hash):
            raise AppError("Senha atual incorreta", status_code=400)
        self._store.update_password(user_id, hash_password(new_password))
        return MessageResponse(message="Password updated successfully.")

    def delete_account(self, user_id: str, *, password: str | None = None) -> MessageResponse:
        user = self._store.get_by_id(user_id)
        if user is None:
            raise AppError("Usuário não encontrado", status_code=404)
        if not user.is_anonymous:
            if not password or not verify_password(password, user.password_hash):
                raise AppError("Senha incorreta", status_code=400)
        self._purge_user_assets(user_id)
        self._store.delete_user(user_id)
        return MessageResponse(message="Account deleted.")

    def _purge_user_assets(self, user_id: str) -> None:
        self._finance.purge_user_data(user_id)
        self._alerts.purge_user_alerts(user_id)
        self._reset_store.purge_user_tokens(user_id)
        avatar = _AVATARS_DIR / f"{user_id}.jpg"
        if avatar.is_file():
            avatar.unlink(missing_ok=True)

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
            photo_url=user.photo_url,
        )


def _is_jpeg(content: bytes) -> bool:
    return len(content) >= 3 and content[0:3] == b"\xff\xd8\xff"


def _is_png(content: bytes) -> bool:
    return len(content) >= 8 and content[0:8] == b"\x89PNG\r\n\x1a\n"
