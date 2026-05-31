import asyncio
from unittest.mock import AsyncMock

from app.services.global_market_service import GlobalMarketService


def test_list_exchange_market_uses_nested_tickers():
    client = AsyncMock()
    client.list_exchange_tickers.return_value = (
        [
            {"name": "Apple Inc", "symbol": "AAPL", "has_eod": True},
            {"name": "Microsoft Corporation", "symbol": "MSFT", "has_eod": True},
        ],
        {"total": 2, "limit": 25, "offset": 0},
    )
    client.get_eod_range.return_value = [
        {"symbol": "AAPL", "close": 312.0, "date": "2026-05-29T00:00:00+0000", "exchange": "XNAS"},
        {"symbol": "AAPL", "close": 309.0, "date": "2026-05-28T00:00:00+0000", "exchange": "XNAS"},
        {"symbol": "MSFT", "close": 450.0, "date": "2026-05-29T00:00:00+0000", "exchange": "XNAS"},
        {"symbol": "MSFT", "close": 445.0, "date": "2026-05-28T00:00:00+0000", "exchange": "XNAS"},
    ]

    service = GlobalMarketService(client=client)
    result = asyncio.run(
        service.list_exchange_market(
            "XNAS",
            exchange_name="NASDAQ",
            country_code="US",
        )
    )

    assert result.exchange_mic == "XNAS"
    assert result.count == 2
    assert {item.symbol for item in result.items} == {"AAPL", "MSFT"}
    client.list_exchange_tickers.assert_awaited_once()
    client.get_eod_range.assert_awaited_once()
