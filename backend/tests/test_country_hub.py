import asyncio
from unittest.mock import AsyncMock

from app.clients.brapi.models import MarketQuote
from app.services.global_market_service import GlobalMarketService


def test_country_exchange_segments_fallback():
    service = GlobalMarketService(client=AsyncMock())
    segments = asyncio.run(service._country_exchange_segments("DE"))
    assert segments
    assert segments[0][0] == "XETRA"


def test_get_country_hub_us_builds_sections():
    client = AsyncMock()
    client.map_quotes_with_change.return_value = [
        MarketQuote(
            symbol="AAPL",
            name="Apple",
            price=190.0,
            change_percent=1.2,
            category="stocks",
            volume=50_000_000.0,
            exchange="XNAS",
        ),
    ]

    service = GlobalMarketService(client=client)
    result = asyncio.run(service.get_country_hub("US"))

    assert result.country_code == "US"
    assert result.sections
