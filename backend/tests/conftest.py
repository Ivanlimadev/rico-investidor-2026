import pytest
from fastapi.testclient import TestClient

from app.config import settings
from app.db.init_db import init_database
from app.db.session import _engine_for_url
from app.main import create_app


@pytest.fixture
def auth_env(tmp_path, monkeypatch):
    secret = "test-secret-key-for-jwt-auth-32chars"
    users_path = tmp_path / "users.json"
    db_path = tmp_path / "test.db"
    monkeypatch.setattr(settings, "auth_secret", secret)
    monkeypatch.setattr(settings, "auth_users_path", users_path)
    monkeypatch.setattr(settings, "auth_token_ttl_seconds", 3600)
    monkeypatch.setattr(settings, "auth_rate_limit_per_minute", 10_000)
    monkeypatch.setattr(settings, "database_url", f"sqlite:///{db_path}")
    _engine_for_url.cache_clear()
    init_database()
    return {"secret": secret, "users_path": users_path, "database_url": settings.database_url}


@pytest.fixture
def client(auth_env):
    return TestClient(create_app())


@pytest.fixture(autouse=True)
def isolated_test_settings(monkeypatch, tmp_path):
    """Evita que ~/.Secrets ou backend/.env local afetem a suíte de testes."""
    db_path = tmp_path / "test.db"
    monkeypatch.setattr(settings, "auth_secret", "")
    monkeypatch.setattr(settings, "docs_enabled", True)
    monkeypatch.setattr(settings, "auth_rate_limit_per_minute", 10_000)
    monkeypatch.setattr(settings, "auth_users_path", tmp_path / "users.json")
    if not getattr(settings, "database_url", "").startswith(f"sqlite:///{tmp_path}"):
        monkeypatch.setattr(settings, "database_url", f"sqlite:///{db_path}")
        _engine_for_url.cache_clear()
        init_database()
