import asyncio
from unittest.mock import AsyncMock

from app.services.global_market_service import GlobalMarketService


def test_list_exchange_market_falls_back_to_exchange_eod():
    client = AsyncMock()
    client.list_exchange_tickers.return_value = ([], {"total": 1, "limit": 25, "offset": 0})
    client.get_eod_range.return_value = []
    client.get_exchange_eod.return_value = (
        [
            {"symbol": "SAP", "close": 180.0, "date": "2025-05-01T00:00:00+0000"},
            {"symbol": "SAP", "close": 175.0, "date": "2025-04-30T00:00:00+0000"},
        ],
        {"total": 1, "limit": 25, "offset": 0},
    )

    service = GlobalMarketService(client=client)
    result = asyncio.run(
        service.list_exchange_market(
            "XETR",
            exchange_name="Xetra",
            country_code="DE",
        )
    )

    assert result.exchange_mic == "XETR"
    assert result.count == 1
    assert result.items[0].symbol == "SAP"
    assert result.items[0].price == 180.0
    client.list_exchange_tickers.assert_awaited_once()
    client.get_exchange_eod.assert_awaited_once()
