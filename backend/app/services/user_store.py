import json
import secrets
from dataclasses import dataclass
from pathlib import Path

from app.config import settings
from app.core.exceptions import AppError


@dataclass(frozen=True)
class StoredUser:
    id: str
    email: str
    name: str
    password_hash: str
    is_anonymous: bool = False


class UserStore:
    def __init__(self, path: Path | None = None) -> None:
        self._path = path or settings.auth_users_path

    def _load(self) -> dict:
        if not self._path.exists():
            return {"users": []}
        return json.loads(self._path.read_text(encoding="utf-8"))

    def _save(self, data: dict) -> None:
        self._path.parent.mkdir(parents=True, exist_ok=True)
        self._path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

    def get_by_id(self, user_id: str) -> StoredUser | None:
        for raw in self._load()["users"]:
            if raw["id"] == user_id:
                return self._to_user(raw)
        return None

    def get_by_email(self, email: str) -> StoredUser | None:
        normalized = email.strip().lower()
        for raw in self._load()["users"]:
            if raw["email"] == normalized:
                return self._to_user(raw)
        return None

    def get_by_device_id(self, device_id: str) -> StoredUser | None:
        email = self._device_email(device_id)
        return self.get_by_email(email)

    def create_user(
        self,
        *,
        email: str,
        name: str,
        password_hash: str,
        is_anonymous: bool = False,
    ) -> StoredUser:
        normalized = email.strip().lower()
        if self.get_by_email(normalized):
            raise AppError("E-mail já cadastrado", status_code=409)

        user = StoredUser(
            id=secrets.token_urlsafe(16),
            email=normalized,
            name=name.strip(),
            password_hash=password_hash,
            is_anonymous=is_anonymous,
        )
        data = self._load()
        data["users"].append(
            {
                "id": user.id,
                "email": user.email,
                "name": user.name,
                "password_hash": user.password_hash,
                "is_anonymous": user.is_anonymous,
            }
        )
        self._save(data)
        return user

    def get_or_create_device_user(self, device_id: str) -> StoredUser:
        existing = self.get_by_device_id(device_id)
        if existing:
            return existing

        from app.services.auth_service import hash_password

        return self.create_user(
            email=self._device_email(device_id),
            name="Investidor",
            password_hash=hash_password(secrets.token_urlsafe(32)),
            is_anonymous=True,
        )

    @staticmethod
    def _device_email(device_id: str) -> str:
        safe = device_id.strip().lower().replace("@", "_")
        return f"device+{safe}@rico.local"

    @staticmethod
    def _to_user(raw: dict) -> StoredUser:
        return StoredUser(
            id=raw["id"],
            email=raw["email"],
            name=raw["name"],
            password_hash=raw["password_hash"],
            is_anonymous=bool(raw.get("is_anonymous", False)),
        )
