import asyncio
from unittest.mock import AsyncMock

from app.services.global_market_service import GlobalMarketService


async def _eod_range(symbols, *, date_from=None, date_to=None, exchange=None, limit=1000):
    rows = []
    for symbol in symbols:
        close = 100.0 if symbol == "AAPL" else 200.0
        rows.append(
            {
                "symbol": symbol,
                "close": close,
                "date": "2026-05-29T00:00:00+0000",
                "exchange": exchange or "XNAS",
            }
        )
        rows.append(
            {
                "symbol": symbol,
                "close": close * 0.99,
                "date": "2026-05-28T00:00:00+0000",
                "exchange": exchange or "XNAS",
            }
        )
    return rows


def test_list_us_market_paginates_across_exchanges():
    client = AsyncMock()

    async def ticker_side_effect(mic: str, *, limit: int = 100, offset: int = 0, search: str | None = None):
        if mic == "XNAS":
            rows = [{"symbol": "AAPL", "name": "Apple Inc"}] if offset == 0 else [{"symbol": "MSFT", "name": "Microsoft"}]
            return (rows, {"total": 2, "limit": limit, "offset": offset})
        if mic == "XNYS":
            return (
                [{"symbol": "IBM", "name": "IBM"}],
                {"total": 1, "limit": limit, "offset": offset},
            )
        return ([], {"total": 0, "limit": limit, "offset": offset})

    client.list_exchange_tickers.side_effect = ticker_side_effect
    client.get_eod_range.side_effect = _eod_range
    client.get_exchange_eod.return_value = ([], {"total": 0, "limit": 1, "offset": 0})

    service = GlobalMarketService(client=client)
    page1 = asyncio.run(service.list_us_market(category="stocks", page=1, limit=1))
    page2 = asyncio.run(service.list_us_market(category="stocks", page=2, limit=1))

    assert page1.total == 3
    assert page1.items[0].symbol == "AAPL"
    assert page2.items[0].symbol == "MSFT"


def test_count_us_stocks_sums_exchange_totals():
    client = AsyncMock()
    client.list_exchange_tickers.side_effect = [
        ([{"symbol": "AAPL"}], {"total": 10000}),
        ([{"symbol": "IBM"}], {"total": 6000}),
        ([{"symbol": "SPY"}], {"total": 2000}),
    ]

    service = GlobalMarketService(client=client)
    total = asyncio.run(service.count_us_stocks())

    assert total == 18000


def test_list_us_market_search_ignores_exchange_without_results():
    from app.core.exceptions import UpstreamError

    client = AsyncMock()

    async def ticker_side_effect(mic: str, *, limit: int = 100, offset: int = 0, search: str | None = None):
        if mic == "XNAS":
            return ([{"symbol": "AAPL", "name": "Apple Inc"}], {"total": 1, "limit": limit, "offset": offset})
        raise UpstreamError("no results", status_code=502)

    client.list_exchange_tickers.side_effect = ticker_side_effect
    client.get_eod_range.side_effect = _eod_range

    service = GlobalMarketService(client=client)
    result = asyncio.run(service.list_us_market(category="stocks", page=1, limit=10, search="apple"))

    assert result.count == 1
    assert result.items[0].symbol == "AAPL"
    assert result.items[0].exchange == "XNAS"
