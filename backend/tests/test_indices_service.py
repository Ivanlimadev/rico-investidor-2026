import asyncio
from unittest.mock import AsyncMock

from app.domain.indices.models import IndexQuote
from app.services.indices_service import IndicesService


def test_explore_paginates_catalog():
    client = AsyncMock()
    client.get_quotes_raw = AsyncMock(
        return_value=[
            {
                "symbol": "^BVSP",
                "longName": "IBOVESPA",
                "regularMarketPrice": 128450.0,
                "regularMarketChangePercent": 0.67,
            }
        ]
    )
    service = IndicesService(client=client)

    result = asyncio.run(service.explore(group="brasil", page=1, limit=2))

    assert result.total >= 2
    assert result.items[0].symbol == "^BVSP"
    client.get_quotes_raw.assert_awaited_once()
