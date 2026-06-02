from fastapi.testclient import TestClient

from app.config import settings
from app.main import create_app


def test_auth_routes_have_stricter_rate_limit(tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "auth_secret", "test-secret-key-for-jwt-auth-32chars")
    monkeypatch.setattr(settings, "auth_users_path", tmp_path / "users.json")
    monkeypatch.setattr(settings, "auth_rate_limit_per_minute", 3)
    monkeypatch.setattr(settings, "rate_limit_per_minute", 100)

    with TestClient(create_app()) as client:
        for _ in range(3):
            response = client.post("/v1/auth/anonymous", json={"device_id": "device-rate-limit-test"})
            assert response.status_code == 200

        blocked = client.post("/v1/auth/anonymous", json={"device_id": "device-rate-limit-test"})
        assert blocked.status_code == 429
        assert "autenticação" in blocked.json()["detail"].lower()


def test_logo_paths_skip_rate_limit(monkeypatch):
    monkeypatch.setattr(settings, "rate_limit_per_minute", 2)
    monkeypatch.setattr(settings, "auth_rate_limit_per_minute", 2)
    monkeypatch.setattr(settings, "auth_secret", "")

    with TestClient(create_app()) as client:
        for _ in range(5):
            response = client.get("/v1/crypto/BTC/logo.png")
            assert response.status_code != 429


def test_non_auth_routes_use_global_rate_limit(monkeypatch):
    monkeypatch.setattr(settings, "auth_rate_limit_per_minute", 2)
    monkeypatch.setattr(settings, "rate_limit_per_minute", 5)
    monkeypatch.setattr(settings, "auth_secret", "")

    with TestClient(create_app()) as client:
        for _ in range(5):
            response = client.get("/v1/meta/providers")
            assert response.status_code == 200

        blocked = client.get("/v1/meta/providers")
        assert blocked.status_code == 429
        assert "requisições" in blocked.json()["detail"].lower()
