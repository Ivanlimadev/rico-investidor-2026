import pytest

from app.config import settings
from app.core.production_guard import validate_production_settings


def test_production_requires_bolsai_key(monkeypatch):
    monkeypatch.setattr(settings, "app_env", "production")
    monkeypatch.setattr(settings, "auth_secret", "x" * 32)
    monkeypatch.setattr(settings, "docs_enabled", False)
    monkeypatch.setattr(settings, "open_finance_api_key", "test-open-finance")
    monkeypatch.setattr(settings, "bolsai_api_key", "")

    with pytest.raises(RuntimeError, match="BOLSAI_API_KEY"):
        validate_production_settings()
