import pytest

from app.config import settings
from app.core.production_guard import validate_production_settings


def test_production_guard_rejects_weak_config(monkeypatch):
    monkeypatch.setattr(settings, "app_env", "production")
    monkeypatch.setattr(settings, "auth_secret", "short")
    monkeypatch.setattr(settings, "docs_enabled", True)
    monkeypatch.setattr(settings, "open_finance_api_key", "")

    with pytest.raises(RuntimeError, match="AUTH_SECRET"):
        validate_production_settings()


def test_production_guard_passes_with_valid_config(monkeypatch):
    monkeypatch.setattr(settings, "app_env", "production")
    monkeypatch.setattr(settings, "auth_secret", "x" * 32)
    monkeypatch.setattr(settings, "docs_enabled", False)
    monkeypatch.setattr(settings, "open_finance_api_key", "of-key-test-12345")
    validate_production_settings()
