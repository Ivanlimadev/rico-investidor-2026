import asyncio
from unittest.mock import AsyncMock, patch

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
    async def passthrough(response):
        return response

    with (
        patch.object(service, "_enrich_screener_with_bolsai_dy", passthrough),
        patch(
            "app.services.quote_service.br_proventos_service.fetch_dividend_yields_batch",
            AsyncMock(return_value={}),
        ),
    ):
        result = asyncio.run(service.get_stock_heatmap(limit=2))

    assert result.count == 2
    assert [item.symbol for item in result.items] == ["PETR4", "VALE3"]
    assert result.items[0].volume == 50_000_000


def test_get_us_heatmap_ranks_nasdaq_candidates_by_volume():
    client = AsyncMock()

    async def fake_eod_rows(symbols, **kwargs):
        return [
            {
                "symbol": "NVDA",
                "date": "2026-06-01",
                "close": 900.0,
                "open": 890.0,
                "high": 910.0,
                "low": 880.0,
                "volume": 120_000_000,
            },
            {
                "symbol": "NVDA",
                "date": "2026-05-30",
                "close": 878.0,
                "open": 870.0,
                "high": 885.0,
                "low": 865.0,
                "volume": 100_000_000,
            },
            {
                "symbol": "AAPL",
                "date": "2026-06-01",
                "close": 190.0,
                "open": 188.0,
                "high": 191.0,
                "low": 187.0,
                "volume": 80_000_000,
            },
            {
                "symbol": "AAPL",
                "date": "2026-05-30",
                "close": 188.0,
                "open": 186.0,
                "high": 189.0,
                "low": 185.0,
                "volume": 70_000_000,
            },
            {
                "symbol": "TSLA",
                "date": "2026-06-01",
                "close": 250.0,
                "open": 248.0,
                "high": 252.0,
                "low": 246.0,
                "volume": 50_000,
            },
            {
                "symbol": "TSLA",
                "date": "2026-05-30",
                "close": 248.0,
                "open": 245.0,
                "high": 249.0,
                "low": 244.0,
                "volume": 48_000,
            },
        ]

    service = GlobalMarketService(client=client)
    with patch.object(service, "_build_us_heatmap_items", AsyncMock(return_value=[
        MarketQuote(
            symbol="NVDA",
            name="NVIDIA",
            price=900.0,
            change_percent=2.5,
            category="stocks",
            provider="marketstack",
            volume=120_000_000,
            exchange="XNAS",
        ),
        MarketQuote(
            symbol="AAPL",
            name="Apple",
            price=190.0,
            change_percent=1.0,
            category="stocks",
            provider="marketstack",
            volume=80_000_000,
            exchange="XNAS",
        ),
    ])):
        result = asyncio.run(service.get_us_heatmap(limit=2))

    assert result.count == 2
    assert [item.symbol for item in result.items] == ["NVDA", "AAPL"]
    assert result.items[0].exchange == "XNAS"
