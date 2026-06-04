import pytest
from fastapi.testclient import TestClient

from app.config import settings
from app.core.open_finance_user import open_finance_client_id_for_user
from app.main import app
from app.services.open_finance_store import OpenFinanceStore


@pytest.fixture
def auth_env(tmp_path, monkeypatch):
    secret = "test-secret-key-for-jwt-auth-32chars"
    users_path = tmp_path / "users.json"
    of_path = tmp_path / "open_finance_links.json"
    monkeypatch.setattr(settings, "auth_secret", secret)
    monkeypatch.setattr(settings, "auth_users_path", users_path)
    monkeypatch.setattr(settings, "open_finance_store_path", of_path)
    monkeypatch.setattr(settings, "open_finance_api_key", "")
    monkeypatch.setattr(settings, "app_env", "development")
    return {"of_path": of_path}


@pytest.fixture
def client(auth_env):
    return TestClient(app)


def _token_for(client: TestClient, device_id: str) -> str:
    return client.post("/v1/auth/anonymous", json={"device_id": device_id}).json()["access_token"]


def test_open_finance_status_ignores_foreign_client_user_id(client, auth_env):
    store = OpenFinanceStore(path=auth_env["of_path"])
    victim_id = "rico-user-victim-id-abc"
    store.add_item_id(victim_id, "item-victim-12345678")

    attacker_token = _token_for(client, "attacker-device-12345678")
    response = client.get(
        "/v1/open-finance/status",
        params={"client_user_id": victim_id},
        headers={"Authorization": f"Bearer {attacker_token}"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["linked_items"] == 0
    assert body["client_user_id"] != victim_id


def test_open_finance_client_id_is_derived_from_jwt_sub():
    assert open_finance_client_id_for_user("abc-123") == "rico-user-abc-123"


def test_open_finance_requires_auth_when_secret_set(client, auth_env):
    response = client.get("/v1/open-finance/status")
    assert response.status_code == 401
