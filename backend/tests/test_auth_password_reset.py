import pytest
from fastapi.testclient import TestClient

from app.main import create_app
from app.services.auth_service import AuthService, verify_password
from app.services.password_reset_store import PasswordResetStore
from app.services.user_store import UserStore
from tests.test_auth import auth_env  # noqa: F401


@pytest.fixture
def client(auth_env):  # noqa: F811
    return TestClient(create_app())


def test_forgot_password_always_returns_generic_message(client):
    response = client.post(
        "/v1/auth/forgot-password",
        json={"email": "missing@example.com"},
    )
    assert response.status_code == 200
    assert "account exists" in response.json()["message"].lower()


def test_reset_password_flow(client, auth_env, caplog):
    client.post(
        "/v1/auth/register",
        json={
            "email": "reset@example.com",
            "password": "Senha-forte123!",
            "name": "Reset User",
        },
    )

    with caplog.at_level("INFO"):
        forgot = client.post(
            "/v1/auth/forgot-password",
            json={"email": "reset@example.com"},
        )
    assert forgot.status_code == 200

    store = UserStore()
    user = store.get_by_email("reset@example.com")
    assert user is not None

    reset_store = PasswordResetStore()
    raw_token = reset_store.create_token(user.id)

    reset = client.post(
        "/v1/auth/reset-password",
        json={"token": raw_token, "new_password": "Nova-senha456!"},
    )
    assert reset.status_code == 200

    login_old = client.post(
        "/v1/auth/login",
        json={"email": "reset@example.com", "password": "Senha-forte123!"},
    )
    assert login_old.status_code == 401

    login_new = client.post(
        "/v1/auth/login",
        json={"email": "reset@example.com", "password": "Nova-senha456!"},
    )
    assert login_new.status_code == 200


def test_change_password_requires_auth(client):
    client.post(
        "/v1/auth/register",
        json={
            "email": "change@example.com",
            "password": "Senha-forte123!",
            "name": "Change User",
        },
    )
    token = client.post(
        "/v1/auth/login",
        json={"email": "change@example.com", "password": "Senha-forte123!"},
    ).json()["access_token"]

    response = client.post(
        "/v1/auth/change-password",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "current_password": "Senha-forte123!",
            "new_password": "Outra-senha789!",
        },
    )
    assert response.status_code == 200

    login = client.post(
        "/v1/auth/login",
        json={"email": "change@example.com", "password": "Outra-senha789!"},
    )
    assert login.status_code == 200


def test_delete_account_requires_password(client):
    register = client.post(
        "/v1/auth/register",
        json={
            "email": "delete@example.com",
            "password": "Senha-forte123!",
            "name": "Delete User",
        },
    )
    assert register.status_code == 200
    token = register.json()["access_token"]

    bad = client.request(
        "DELETE",
        "/v1/auth/me",
        headers={"Authorization": f"Bearer {token}"},
        json={"password": "errada"},
    )
    assert bad.status_code == 400

    ok = client.request(
        "DELETE",
        "/v1/auth/me",
        headers={"Authorization": f"Bearer {token}"},
        json={"password": "Senha-forte123!"},
    )
    assert ok.status_code == 200

    login = client.post(
        "/v1/auth/login",
        json={"email": "delete@example.com", "password": "Senha-forte123!"},
    )
    assert login.status_code == 401
