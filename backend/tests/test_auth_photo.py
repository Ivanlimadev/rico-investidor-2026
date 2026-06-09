import base64

import pytest
from fastapi.testclient import TestClient

from app.main import create_app
from app.services.auth_service import _AVATARS_DIR
from tests.conftest import auth_env  # noqa: F401

_MIN_JPEG = base64.b64decode(
    "/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////"
    "2wBDAf//////////////////////////////////////////////////////////////////////////////////////wAARCAABAAEDAREAAhEBAxEB"
    "/8QAFQABAQAAAAAAAAAAAAAAAAAAAAb/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAA"
    "AAAA/9oADAMBAAIRAxEAPwCwAA8A/9k="
)


@pytest.fixture
def client(auth_env):  # noqa: F811
    return TestClient(create_app())


def _register_and_token(client: TestClient) -> tuple[str, str]:
    register = client.post(
        "/v1/auth/register",
        json={
            "email": "photo@example.com",
            "password": "Senha-forte123!",
            "name": "Photo User",
        },
    )
    assert register.status_code == 200
    token = register.json()["access_token"]
    user_id = client.get(
        "/v1/auth/me",
        headers={"Authorization": f"Bearer {token}"},
    ).json()["id"]
    return token, user_id


def test_upload_profile_photo(client):
    token, user_id = _register_and_token(client)

    response = client.post(
        "/v1/auth/me/photo",
        headers={"Authorization": f"Bearer {token}"},
        files={"file": ("avatar.jpg", _MIN_JPEG, "image/jpeg")},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["photo_url"] == f"/static/avatars/{user_id}.jpg"
    assert (_AVATARS_DIR / f"{user_id}.jpg").read_bytes() == _MIN_JPEG


def test_upload_profile_photo_rejects_large_file(client):
    token, _ = _register_and_token(client)
    oversized = _MIN_JPEG + (b"\x00" * (2 * 1024 * 1024))

    response = client.post(
        "/v1/auth/me/photo",
        headers={"Authorization": f"Bearer {token}"},
        files={"file": ("avatar.jpg", oversized, "image/jpeg")},
    )
    assert response.status_code == 400


def test_upload_profile_photo_rejects_invalid_type(client):
    token, _ = _register_and_token(client)

    response = client.post(
        "/v1/auth/me/photo",
        headers={"Authorization": f"Bearer {token}"},
        files={"file": ("avatar.txt", b"not-an-image", "text/plain")},
    )
    assert response.status_code == 400


def test_upload_profile_photo_requires_auth(client):
    response = client.post(
        "/v1/auth/me/photo",
        files={"file": ("avatar.jpg", _MIN_JPEG, "image/jpeg")},
    )
    assert response.status_code == 401
