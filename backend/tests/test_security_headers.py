from unittest.mock import AsyncMock, patch

from fastapi.testclient import TestClient

from app.clients.brapi.models import MarketQuoteBatchResponse
from app.domain.home.models import FeaturedFiisFeed, HomeFeedResponse, MarketCounts
from app.main import create_app


def test_security_headers_are_present():
    with TestClient(create_app()) as client:
        response = client.get("/health")
        assert response.status_code == 200
        assert response.headers.get("X-Content-Type-Options") == "nosniff"
        assert response.headers.get("X-Frame-Options") == "DENY"
        assert response.headers.get("Referrer-Policy") == "strict-origin-when-cross-origin"


def test_home_feed_has_cache_control():
    feed = HomeFeedResponse(
        featured_us_stocks=MarketQuoteBatchResponse(items=[], count=0, provider="marketstack"),
        featured_stocks=MarketQuoteBatchResponse(items=[], count=0),
        featured_fiis=FeaturedFiisFeed(),
        market_counts=MarketCounts(),
    )

    with (
        patch("app.services.home_service.home_service.get_feed", new_callable=AsyncMock) as mock_feed,
        patch("app.config.settings.quote_cache_ttl_seconds", 300),
        TestClient(create_app()) as client,
    ):
        mock_feed.return_value = feed
        response = client.get("/v1/home/feed")

    assert response.status_code == 200
    assert response.headers.get("Cache-Control") == "public, max-age=300"
