import secrets
from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.exceptions import AppError
from app.db.models import UserRow
from app.db.session import get_session_factory


@dataclass(frozen=True)
class StoredUser:
    id: str
    email: str
    name: str
    password_hash: str
    is_anonymous: bool = False
    photo_url: str | None = None


class UserStore:
    def __init__(self, session_factory=None) -> None:
        self._session_factory = session_factory or get_session_factory()

    def _to_user(self, row: UserRow) -> StoredUser:
        return StoredUser(
            id=row.id,
            email=row.email,
            name=row.name,
            password_hash=row.password_hash,
            is_anonymous=row.is_anonymous,
            photo_url=row.photo_url,
        )

    def get_by_id(self, user_id: str) -> StoredUser | None:
        with self._session_factory() as session:
            row = session.get(UserRow, user_id)
            return self._to_user(row) if row else None

    def get_by_email(self, email: str) -> StoredUser | None:
        normalized = email.strip().lower()
        with self._session_factory() as session:
            row = session.scalar(select(UserRow).where(UserRow.email == normalized))
            return self._to_user(row) if row else None

    def get_by_device_id(self, device_id: str) -> StoredUser | None:
        return self.get_by_email(self._device_email(device_id))

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
            raise AppError(
                "Não foi possível criar a conta com estes dados",
                status_code=400,
            )

        user = StoredUser(
            id=secrets.token_urlsafe(16),
            email=normalized,
            name=name.strip(),
            password_hash=password_hash,
            is_anonymous=is_anonymous,
        )
        with self._session_factory() as session:
            session.add(
                UserRow(
                    id=user.id,
                    email=user.email,
                    name=user.name,
                    password_hash=user.password_hash,
                    is_anonymous=user.is_anonymous,
                )
            )
            try:
                session.commit()
            except IntegrityError as exc:
                session.rollback()
                raise AppError(
                    "Não foi possível criar a conta com estes dados",
                    status_code=400,
                ) from exc
        return user

    def update_password(self, user_id: str, password_hash: str) -> StoredUser:
        with self._session_factory() as session:
            row = session.get(UserRow, user_id)
            if row is None:
                raise AppError("Usuário não encontrado", status_code=404)
            row.password_hash = password_hash
            session.commit()
            session.refresh(row)
            return self._to_user(row)

    def delete_user(self, user_id: str) -> None:
        with self._session_factory() as session:
            row = session.get(UserRow, user_id)
            if row is None:
                raise AppError("Usuário não encontrado", status_code=404)
            session.delete(row)
            session.commit()

    def update_photo_url(self, user_id: str, photo_url: str) -> StoredUser:
        with self._session_factory() as session:
            row = session.get(UserRow, user_id)
            if row is None:
                raise AppError("Usuário não encontrado", status_code=404)
            row.photo_url = photo_url
            session.commit()
            session.refresh(row)
            return self._to_user(row)

    def update_name(self, user_id: str, name: str) -> StoredUser:
        cleaned = name.strip()
        if len(cleaned) < 2:
            raise AppError("Nome inválido", status_code=400)
        with self._session_factory() as session:
            row = session.get(UserRow, user_id)
            if row is None:
                raise AppError("Usuário não encontrado", status_code=404)
            row.name = cleaned[:80]
            session.commit()
            session.refresh(row)
            return self._to_user(row)

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
