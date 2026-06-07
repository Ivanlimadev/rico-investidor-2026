from __future__ import annotations

from pathlib import Path

from alembic import command
from alembic.config import Config

from app.config import settings

_BACKEND_ROOT = Path(__file__).resolve().parents[2]


def run_alembic_upgrade() -> None:
    config = Config(str(_BACKEND_ROOT / "alembic.ini"))
    config.set_main_option("sqlalchemy.url", settings.database_url)
    command.upgrade(config, "head")
