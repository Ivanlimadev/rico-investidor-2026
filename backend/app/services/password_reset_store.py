from __future__ import annotations

import hashlib
import secrets
import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy import delete, select

from app.core.exceptions import AppError
from app.db.models import PasswordResetTokenRow
from app.db.session import get_session_factory

RESET_TOKEN_TTL_HOURS = 1


def hash_reset_token(raw_token: str) -> str:
    return hashlib.sha256(raw_token.encode("utf-8")).hexdigest()


class PasswordResetStore:
    def __init__(self, session_factory=None) -> None:
        self._session_factory = session_factory or get_session_factory()

    def create_token(self, user_id: str) -> str:
        raw_token = secrets.token_urlsafe(32)
        token_hash = hash_reset_token(raw_token)
        expires_at = datetime.now(UTC) + timedelta(hours=RESET_TOKEN_TTL_HOURS)

        with self._session_factory() as session:
            session.execute(
                delete(PasswordResetTokenRow).where(
                    PasswordResetTokenRow.user_id == user_id,
                    PasswordResetTokenRow.used_at.is_(None),
                )
            )
            session.add(
                PasswordResetTokenRow(
                    id=str(uuid.uuid4()),
                    user_id=user_id,
                    token_hash=token_hash,
                    expires_at=expires_at,
                )
            )
            session.commit()
        return raw_token

    def consume_token(self, raw_token: str) -> str:
        token_hash = hash_reset_token(raw_token.strip())
        now = datetime.now(UTC)

        with self._session_factory() as session:
            row = session.scalar(
                select(PasswordResetTokenRow).where(PasswordResetTokenRow.token_hash == token_hash)
            )
            if row is None:
                raise AppError("Link de redefinição inválido ou expirado", status_code=400)
            if row.used_at is not None:
                raise AppError("Este link já foi utilizado", status_code=400)
            expires_at = row.expires_at
            if expires_at.tzinfo is None:
                expires_at = expires_at.replace(tzinfo=UTC)
            if expires_at < now:
                raise AppError("Link de redefinição expirado", status_code=400)

            row.used_at = now
            user_id = row.user_id
            session.commit()
            return user_id
