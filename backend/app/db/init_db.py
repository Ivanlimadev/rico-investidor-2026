from __future__ import annotations

import json
import logging
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.db.base import Base
from app.db.migrations import run_alembic_upgrade
from app.db.models import UserRow
from app.db.session import get_engine, get_session_factory, is_postgres_url

logger = logging.getLogger(__name__)


def init_database() -> None:
    if is_postgres_url(settings.database_url):
        run_alembic_upgrade()
    else:
        engine = get_engine()
        Base.metadata.create_all(bind=engine)
    _migrate_users_json_if_needed()


def _migrate_users_json_if_needed() -> None:
    legacy_path = settings.auth_users_path
    if not legacy_path.is_file():
        return

    factory = get_session_factory()
    with factory() as session:
        if session.scalar(select(UserRow.id).limit(1)) is not None:
            return
        try:
            payload = json.loads(legacy_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            logger.warning("Não foi possível migrar users.json: %s", exc)
            return

        rows = payload.get("users") or []
        if not rows:
            return

        for raw in rows:
            email = str(raw.get("email") or "").strip().lower()
            if not email:
                continue
            session.add(
                UserRow(
                    id=str(raw["id"]),
                    email=email,
                    name=str(raw.get("name") or "Investidor"),
                    password_hash=str(raw.get("password_hash") or ""),
                    is_anonymous=bool(raw.get("is_anonymous", False)),
                )
            )
        session.commit()
        backup = legacy_path.with_suffix(".json.migrated")
        if not backup.exists():
            legacy_path.rename(backup)
        logger.info("Migrados %s usuários de %s para o banco", len(rows), legacy_path)
