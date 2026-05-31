from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient

from app.clients.brapi.models import MarketQuote, MarketQuoteBatchResponse
from app.domain.fii.models import FiiScreenerItem, FiiScreenerResponse
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
    stocks = MarketQuoteBatchResponse(
        items=[
            MarketQuote(
                symbol="PETR4",
                name="Petrobras",
                price=43.44,
                change_percent=0.09,
                category="acoes_br",
            )
        ],
        count=1,
    )
    fiis = FiiScreenerResponse(
        data=[
            FiiScreenerItem(
                ticker="HGLG11",
                name="CSHG Logística",
                close_price=154.7,
                dividend_yield_ttm=8.5,
                pvp=0.93,
            )
        ],
        count=1,
        total=1,
        offset=0,
        limit=8,
    )

    with (
        patch(
            "app.services.home_service.global_market_service.list_featured_us",
            new_callable=AsyncMock,
        ) as mock_us_stocks,
        patch("app.services.home_service.quote_service.featured_stocks", new_callable=AsyncMock) as mock_stocks,
        patch("app.services.home_service.fii_service.featured_fiis", new_callable=AsyncMock) as mock_fiis,
        patch("app.services.home_service.fii_service.count_fiis", new_callable=AsyncMock) as mock_count,
        patch(
            "app.services.home_service.quote_service.get_stock_catalog_total",
            new_callable=AsyncMock,
        ) as mock_catalog_total,
        patch(
            "app.services.home_service.currency_service.count_brl_pairs",
            new_callable=AsyncMock,
        ) as mock_currency_count,
        patch(
            "app.services.home_service.treasury_service.count_bonds",
            new_callable=AsyncMock,
        ) as mock_treasury_count,
        patch(
            "app.services.home_service.indices_service.count_indices",
            new_callable=AsyncMock,
        ) as mock_indices_count,
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
        mock_stocks.return_value = stocks
        mock_fiis.return_value = fiis
        mock_count.return_value = 350
        mock_catalog_total.side_effect = [420, 88]
        mock_currency_count.return_value = 9
        mock_treasury_count.return_value = 42
        mock_indices_count.return_value = 21
        mock_crypto_count.return_value = 410
        mock_us_count.return_value = 8
        mock_world_exchanges.return_value = WorldExchangesResponse(total_exchanges=72)

        response = client.get("/v1/home/feed")

    assert response.status_code == 200
    body = response.json()
    assert body["featured_us_stocks"]["items"][0]["symbol"] == "AAPL"
    assert body["featured_stocks"]["items"][0]["symbol"] == "PETR4"
    assert body["featured_fiis"]["data"][0]["ticker"] == "HGLG11"
    assert body["market_counts"]["fiis"] == 350
    assert body["market_counts"]["acoes_br"] == 420
    assert body["market_counts"]["bdr"] == 88
    assert body["market_counts"]["moeda"] == 9
    assert body["market_counts"]["tesouro"] == 42
    assert body["market_counts"]["indices"] == 21
    assert body["market_counts"]["cripto"] == 410
    assert body["market_counts"]["stocks_us"] == 8
    assert body["market_counts"]["world_exchanges"] == 72
    assert body["market_counts"]["etf"] is None
    assert body["macro"] is None
    assert body["provider"] == "brapi"
    assert "generated_at" in body
