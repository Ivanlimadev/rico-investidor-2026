import asyncio
from unittest.mock import AsyncMock

from app.services.global_market_service import GlobalMarketService


def test_country_exchange_segments_fallback():
    service = GlobalMarketService(client=AsyncMock())
    segments = asyncio.run(service._country_exchange_segments("DE"))
    assert segments
    assert segments[0][0] == "XETRA"


def test_get_country_hub_uses_exchange_tickers_for_international():
    client = AsyncMock()
    client.list_exchange_tickers.return_value = (
        [
            {"symbol": "SAP.XETRA", "name": "SAP SE"},
            {"symbol": "SIE.XETRA", "name": "Siemens"},
        ],
        {"total": 2, "limit": 40, "offset": 0},
    )
    client.get_eod_range.return_value = [
        {"symbol": "SAP.XETRA", "close": 180.0, "date": "2025-05-01T00:00:00+0000"},
        {"symbol": "SAP.XETRA", "close": 175.0, "date": "2025-04-30T00:00:00+0000"},
        {"symbol": "SIE.XETRA", "close": 210.0, "date": "2025-05-01T00:00:00+0000"},
        {"symbol": "SIE.XETRA", "close": 205.0, "date": "2025-04-30T00:00:00+0000"},
    ]

    service = GlobalMarketService(client=client)
    result = asyncio.run(service.get_country_hub("DE"))

    assert result.country_code == "DE"
    assert result.sections
    assert any(item.symbol == "SAP.XETRA" for item in result.sections[0].items)
    sap = next(item for item in result.sections[0].items if item.symbol == "SAP.XETRA")
    assert sap.change_percent != 0.0
    client.get_eod_range.assert_awaited()
