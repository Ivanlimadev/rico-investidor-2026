import asyncio
from unittest.mock import AsyncMock

from app.domain.crypto.models import (
    CryptoAvailableResponse,
    CryptoListResponse,
    CryptoQuote,
)
from app.services.crypto_service import CryptoService


def test_explore_paginates_and_fetches_rates():
    client = AsyncMock()
    client.get_crypto_rates.side_effect = [
        CryptoListResponse(
            items=[
                CryptoQuote(symbol="BTC", name="Bitcoin", price=377479.0, change_percent=-1.359, provider="binance"),
                CryptoQuote(symbol="ETH", name="Ethereum", price=19200.0, change_percent=1.2, provider="binance"),
            ],
            count=2,
            provider="binance",
        ),
        CryptoListResponse(
            items=[
                CryptoQuote(symbol="DOGE", name="Dogecoin", price=1.5, change_percent=0.5, provider="binance"),
            ],
            count=1,
            provider="binance",
        ),
    ]

    service = CryptoService(client=client)
    service.list_available = AsyncMock(  # type: ignore[method-assign]
        return_value=CryptoAvailableResponse(coins=["BTC", "ETH", "DOGE"], count=3, provider="binance")
    )

    page1 = asyncio.run(service.explore(page=1, limit=2))
    assert page1.total == 3
    assert page1.total_pages == 2
    assert page1.page == 1
    assert len(page1.items) == 2
    assert page1.items[0].symbol == "BTC"
    assert page1.items[0].price == 377479.0

    page2 = asyncio.run(service.explore(page=2, limit=2))
    assert page2.page == 2
    assert len(page2.items) == 1
    assert page2.items[0].symbol == "DOGE"


def test_explore_filters_major_group():
    service = CryptoService(client=AsyncMock())
    service.list_available = AsyncMock(  # type: ignore[method-assign]
        return_value=CryptoAvailableResponse(coins=["BTC", "ETH", "SHIB"], count=3, provider="binance")
    )
    service._client.get_crypto_rates = AsyncMock(  # type: ignore[attr-defined]
        return_value=CryptoListResponse(
            items=[
                CryptoQuote(symbol="BTC", name="Bitcoin", price=377479.0, provider="binance"),
                CryptoQuote(symbol="ETH", name="Ethereum", price=19200.0, provider="binance"),
            ],
            count=2,
            provider="binance",
        )
    )

    result = asyncio.run(service.explore(group="major", limit=10))

    assert result.total == 2
    assert {item.symbol for item in result.items} == {"BTC", "ETH"}


def test_get_daily_movers_returns_gainers_and_losers():
    client = AsyncMock()
    client.get_all_usdt_tickers = AsyncMock(
        return_value=CryptoListResponse(
            items=[
                CryptoQuote(symbol="BTC", name="Bitcoin", price=100.0, change_percent=5.0, volume=1_000_000, provider="binance"),
                CryptoQuote(symbol="ETH", name="Ethereum", price=50.0, change_percent=2.0, volume=900_000, provider="binance"),
                CryptoQuote(symbol="DOGE", name="Dogecoin", price=1.0, change_percent=-8.0, volume=800_000, provider="binance"),
                CryptoQuote(symbol="SHIB", name="Shiba Inu", price=0.1, change_percent=-3.0, volume=700_000, provider="binance"),
                CryptoQuote(symbol="USDC", name="USD Coin", price=1.0, change_percent=0.1, volume=5_000_000, provider="binance"),
                CryptoQuote(symbol="PEPE", name="Pepe", price=0.01, change_percent=10.0, volume=100, provider="binance"),
            ],
            count=6,
            provider="binance",
        )
    )

    service = CryptoService(client=client)
    result = asyncio.run(service.get_daily_movers(limit=2))

    assert [item.symbol for item in result.gainers] == ["BTC", "ETH"]
    assert [item.symbol for item in result.losers] == ["DOGE", "SHIB"]
    assert result.limit == 2
