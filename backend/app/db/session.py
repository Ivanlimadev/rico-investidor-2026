from __future__ import annotations

from collections.abc import Generator
from functools import lru_cache

from sqlalchemy import create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session, sessionmaker

from app.config import settings


def is_sqlite_url(database_url: str) -> bool:
    return database_url.startswith("sqlite")


def is_postgres_url(database_url: str) -> bool:
    normalized = database_url.lower()
    return normalized.startswith("postgresql") or normalized.startswith("postgres://")


@lru_cache(maxsize=4)
def _engine_for_url(database_url: str) -> Engine:
    if is_sqlite_url(database_url):
        return create_engine(
            database_url,
            future=True,
            connect_args={"check_same_thread": False},
        )

    return create_engine(
        database_url,
        future=True,
        pool_pre_ping=True,
        pool_size=settings.database_pool_size,
        max_overflow=settings.database_max_overflow,
    )


def get_engine() -> Engine:
    return _engine_for_url(settings.database_url)


def get_session_factory() -> sessionmaker[Session]:
    return sessionmaker(bind=get_engine(), autoflush=False, autocommit=False, future=True)


def get_db_session() -> Generator[Session, None, None]:
    session = get_session_factory()()
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()
