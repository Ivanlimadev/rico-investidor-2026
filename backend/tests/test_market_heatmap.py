import asyncio
from unittest.mock import AsyncMock

from app.clients.brapi.models import StockScreenerItem, StockScreenerResponse
from app.clients.brapi.models import MarketQuote
from app.services.global_market_service import GlobalMarketService
from app.services.quote_service import QuoteService


def test_get_stock_heatmap_ranks_by_volume_and_filters_acoes_br():
    client = AsyncMock()
    client.screener_quotes.return_value = StockScreenerResponse(
        items=[
            StockScreenerItem(
                symbol="PETR4",
                name="Petrobras",
                price=38.0,
                change_percent=1.2,
                category="acoes_br",
                volume=50_000_000,
            ),
            StockScreenerItem(
                symbol="BDRX34",
                name="BDR",
                price=10.0,
                change_percent=0.5,
                category="bdr",
                volume=90_000_000,
            ),
            StockScreenerItem(
                symbol="VALE3",
                name="Vale",
                price=62.0,
                change_percent=-0.8,
                category="acoes_br",
                volume=30_000_000,
            ),
            StockScreenerItem(
                symbol="MGLU3",
                name="Magalu",
                price=2.0,
                change_percent=3.0,
                category="acoes_br",
                volume=100_000,
            ),
        ],
        count=4,
        total=4,
    )

    service = QuoteService(client=client)
    result = asyncio.run(service.get_stock_heatmap(limit=2))

    assert result.count == 2
    assert [item.symbol for item in result.items] == ["PETR4", "VALE3"]
    assert result.items[0].volume == 50_000_000


def test_get_us_heatmap_ranks_nasdaq_candidates_by_volume():
    client = AsyncMock()
    client.map_quotes_with_change.return_value = [
        MarketQuote(
            symbol="AAPL",
            name="Apple",
            price=190.0,
            change_percent=1.0,
            category="stocks",
            provider="marketstack",
            volume=80_000_000,
        ),
        MarketQuote(
            symbol="NVDA",
            name="NVIDIA",
            price=900.0,
            change_percent=2.5,
            category="stocks",
            provider="marketstack",
            volume=120_000_000,
        ),
        MarketQuote(
            symbol="TSLA",
            name="Tesla",
            price=250.0,
            change_percent=-1.0,
            category="stocks",
            provider="marketstack",
            volume=50_000,
        ),
    ]

    service = GlobalMarketService(client=client)
    result = asyncio.run(service.get_us_heatmap(limit=2))

    assert result.count == 2
    assert [item.symbol for item in result.items] == ["NVDA", "AAPL"]
    assert result.items[0].exchange == "XNAS"
