from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient

from app.clients.brapi.models import MarketQuote, MarketQuoteBatchResponse
from app.domain.global_markets.models import WorldExchangesResponse
from app.main import app


@pytest.fixture
def client():
    return TestClient(app)


def test_home_feed_shape(client):
    us_stocks = MarketQuoteBatchResponse(
        items=[
            MarketQuote(
                symbol="AAPL",
                name="Apple",
                price=190.0,
                change_percent=1.2,
                category="stocks",
                provider="marketstack",
            )
        ],
        count=1,
        provider="marketstack",
    )

    with (
        patch(
            "app.services.home_service.global_market_service.list_featured_us",
            new_callable=AsyncMock,
        ) as mock_us_stocks,
        patch(
            "app.services.home_service.crypto_service.count_coins",
            new_callable=AsyncMock,
        ) as mock_crypto_count,
        patch(
            "app.services.home_service.global_market_service.count_us_stocks",
            new_callable=AsyncMock,
        ) as mock_us_count,
        patch(
            "app.services.home_service.global_market_service.list_world_exchanges",
            new_callable=AsyncMock,
        ) as mock_world_exchanges,
    ):
        mock_us_stocks.return_value = us_stocks
        mock_crypto_count.return_value = 410
        mock_us_count.return_value = 8
        mock_world_exchanges.return_value = WorldExchangesResponse(total_exchanges=72)

        response = client.get("/v1/home/feed")

    assert response.status_code == 200
    body = response.json()
    assert body["featured_us_stocks"]["items"][0]["symbol"] == "AAPL"
    assert body["featured_stocks"]["items"] == []
    assert body["featured_fiis"]["data"] == []
    assert body["market_counts"]["fiis"] is None
    assert body["market_counts"]["acoes_br"] is None
    assert body["market_counts"]["bdr"] is None
    assert body["market_counts"]["moeda"] is None
    assert body["market_counts"]["tesouro"] is None
    assert body["market_counts"]["indices"] is None
    assert body["market_counts"]["cripto"] == 410
    assert body["market_counts"]["stocks_us"] == 8
    assert body["market_counts"]["world_exchanges"] == 72
    assert body["market_counts"]["etf"] is None
    assert body["macro"] is None
    assert body["provider"] == "marketstack"
    assert "generated_at" in body
