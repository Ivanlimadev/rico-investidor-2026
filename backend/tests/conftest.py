import pytest

from app.config import settings


@pytest.fixture(autouse=True)
def isolated_test_settings(monkeypatch, tmp_path):
    """Evita que ~/.Secrets ou backend/.env local afetem a suíte de testes."""
    monkeypatch.setattr(settings, "auth_secret", "")
    monkeypatch.setattr(settings, "docs_enabled", True)
    monkeypatch.setattr(settings, "auth_users_path", tmp_path / "users.json")
