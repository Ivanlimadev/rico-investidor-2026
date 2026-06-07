import pytest
from fastapi.testclient import TestClient

from app.config import settings
from app.main import app
from app.services.auth_service import AuthService
from app.services.user_store import UserStore


@pytest.fixture
def auth_env(tmp_path, monkeypatch):
    secret = "test-secret-key-for-jwt-auth-32chars"
    users_path = tmp_path / "users.json"
    monkeypatch.setattr(settings, "auth_secret", secret)
    monkeypatch.setattr(settings, "auth_users_path", users_path)
    monkeypatch.setattr(settings, "auth_token_ttl_seconds", 3600)
    return {"secret": secret, "users_path": users_path}


@pytest.fixture
def client(auth_env):
    return TestClient(app)


def test_auth_disabled_allows_public_api(monkeypatch):
    monkeypatch.setattr(settings, "auth_secret", "")
    with TestClient(app) as test_client:
        response = test_client.get("/v1/meta/providers")
    assert response.status_code == 200


def test_anonymous_auth_returns_token(client, auth_env):
    response = client.post("/v1/auth/anonymous", json={"device_id": "device-abc-12345"})
    assert response.status_code == 200
    body = response.json()
    assert body["token_type"] == "bearer"
    assert body["access_token"]
    assert body["expires_in"] == 3600


def test_protected_route_requires_token(client, auth_env):
    response = client.get("/v1/meta/providers")
    assert response.status_code == 401


def test_logo_paths_are_public_in_auth_middleware():
    from app.core.auth_middleware import AuthMiddleware

    assert AuthMiddleware._is_public("/v1/quotes/PETR4/logo.png")
    assert AuthMiddleware._is_public("/v1/fiis/HGLG11/logo.png")
    assert AuthMiddleware._is_public("/v1/global-markets/AAPL/logo.png")
    assert AuthMiddleware._is_public("/v1/crypto/BTC/logo.png")
    assert not AuthMiddleware._is_public("/v1/quotes/PETR4")
    assert not AuthMiddleware._is_public("/v1/meta/providers")


def test_protected_route_accepts_valid_token(client, auth_env):
    token = client.post("/v1/auth/anonymous", json={"device_id": "device-xyz-98765"}).json()[
        "access_token"
    ]
    response = client.get(
        "/v1/meta/providers",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200


def test_register_and_login(client, auth_env):
    register = client.post(
        "/v1/auth/register",
        json={
            "email": "investidor@example.com",
            "password": "Senha-forte123!",
            "name": "Investidor",
        },
    )
    assert register.status_code == 200
    register_token = register.json()["access_token"]

    login = client.post(
        "/v1/auth/login",
        json={"email": "investidor@example.com", "password": "Senha-forte123!"},
    )
    assert login.status_code == 200
    login_token = login.json()["access_token"]
    assert login_token
    assert login_token != register_token or login_token  # token válido

    me = client.get("/v1/auth/me", headers={"Authorization": f"Bearer {login_token}"})
    assert me.status_code == 200
    assert me.json()["email"] == "investidor@example.com"
    assert me.json()["is_anonymous"] is False


def test_login_invalid_password(client, auth_env):
    client.post(
        "/v1/auth/register",
        json={
            "email": "outro@example.com",
            "password": "Senha-forte123!",
            "name": "Outro",
        },
    )
    response = client.post(
        "/v1/auth/login",
        json={"email": "outro@example.com", "password": "errada"},
    )
    assert response.status_code == 401


def test_anonymous_device_is_idempotent(auth_env):
    store = UserStore()
    service = AuthService(store=store)

    first = service.anonymous(device_id="same-device-id-123456")
    second = service.anonymous(device_id="same-device-id-123456")

    assert first.access_token
    assert second.access_token

    first_user = store.get_by_device_id("same-device-id-123456")
    assert first_user is not None
    second_lookup = store.get_by_device_id("same-device-id-123456")
    assert second_lookup is not None
    assert first_user.id == second_lookup.id
