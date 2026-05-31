import pytest
from fastapi.testclient import TestClient

from app.config import settings
from app.domain.auth.password_policy import password_policy_errors, validate_password_strength
from app.main import app


def test_password_policy_requires_mixed_rules():
    assert password_policy_errors("abc") == [
        "mínimo 8 caracteres",
        "pelo menos 1 letra maiúscula",
        "1 número",
        "1 caractere especial",
    ]
    assert password_policy_errors("Senha123!") == []
    assert password_policy_errors("SENHA123!") == []
    assert "pelo menos 1 letra maiúscula" in password_policy_errors("senha123!")


def test_password_policy_rejects_missing_special():
    with pytest.raises(ValueError, match="caractere especial"):
        validate_password_strength("Senha1234")


@pytest.fixture
def auth_client(tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "auth_secret", "test-secret-key-for-jwt-auth-32chars")
    monkeypatch.setattr(settings, "auth_users_path", tmp_path / "users.json")
    return TestClient(app)


def test_register_rejects_weak_password(auth_client):
    response = auth_client.post(
        "/v1/auth/register",
        json={
            "email": "fraco@example.com",
            "password": "senha1234",
            "name": "Fraco",
        },
    )
    assert response.status_code == 422
