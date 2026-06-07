import pytest

from app.config import settings
from app.core.production_guard import validate_production_settings


def test_production_requires_auth_secret(monkeypatch):
    monkeypatch.setattr(settings, "app_env", "production")
    monkeypatch.setattr(settings, "auth_secret", "short")
    monkeypatch.setattr(settings, "docs_enabled", False)
    monkeypatch.setattr(settings, "open_finance_api_key", "test-open-finance")

    with pytest.raises(RuntimeError, match="AUTH_SECRET"):
        validate_production_settings()


def test_production_requires_postgres(monkeypatch):
    monkeypatch.setattr(settings, "app_env", "production")
    monkeypatch.setattr(settings, "auth_secret", "x" * 32)
    monkeypatch.setattr(settings, "docs_enabled", False)
    monkeypatch.setattr(settings, "open_finance_api_key", "test-open-finance")
    monkeypatch.setattr(settings, "database_url", "sqlite:///./data/ricoapp.db")

    with pytest.raises(RuntimeError, match="PostgreSQL"):
        validate_production_settings()


def test_production_ok_with_valid_config(monkeypatch):
    monkeypatch.setattr(settings, "app_env", "production")
    monkeypatch.setattr(settings, "auth_secret", "x" * 32)
    monkeypatch.setattr(settings, "docs_enabled", False)
    monkeypatch.setattr(settings, "open_finance_api_key", "test-open-finance")
    monkeypatch.setattr(
        settings,
        "database_url",
        "postgresql+psycopg://rico:rico@127.0.0.1:5432/ricoapp",
    )

    validate_production_settings()
