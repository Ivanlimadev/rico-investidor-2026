from fastapi.testclient import TestClient

from app.main import create_app


def test_docs_available_when_enabled():
    with TestClient(create_app(docs_enabled=True)) as client:
        assert client.get("/docs").status_code == 200
        assert client.get("/redoc").status_code == 200
        assert client.get("/openapi.json").status_code == 200


def test_docs_hidden_when_disabled():
    with TestClient(create_app(docs_enabled=False)) as client:
        assert client.get("/docs").status_code == 404
        assert client.get("/redoc").status_code == 404
        assert client.get("/openapi.json").status_code == 404


def test_health_stays_public_when_docs_disabled():
    with TestClient(create_app(docs_enabled=False)) as client:
        assert client.get("/health").status_code == 200
