from fastapi.testclient import TestClient

from app.main import create_app


def test_security_headers_are_present():
    with TestClient(create_app()) as client:
        response = client.get("/health")
        assert response.status_code == 200
        assert response.headers.get("X-Content-Type-Options") == "nosniff"
        assert response.headers.get("X-Frame-Options") == "DENY"
        assert response.headers.get("Referrer-Policy") == "strict-origin-when-cross-origin"


def test_featured_quotes_has_cache_control(monkeypatch):
    from app.services.quote_service import quote_service

    async def _fake_featured():
        return {"items": [], "count": 0}

    monkeypatch.setattr(quote_service, "featured_stocks", _fake_featured)
    monkeypatch.setattr("app.config.settings.quote_cache_ttl_seconds", 300)

    with TestClient(create_app()) as client:
        response = client.get("/v1/quotes/featured")
        assert response.status_code == 200
        assert response.headers.get("Cache-Control") == "public, max-age=300"
