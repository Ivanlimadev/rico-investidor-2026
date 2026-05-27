import asyncio
from unittest.mock import AsyncMock

from app.domain.currency.models import (
    CurrencyListResponse,
    CurrencyPairListResponse,
    CurrencyPairSummary,
    CurrencyQuote,
)
from app.services.currency_service import CurrencyService


def test_explore_paginates_and_fetches_rates():
    client = AsyncMock()
    client.get_currency_rates.return_value = CurrencyListResponse(
        items=[
            CurrencyQuote(
                pair="USD-BRL",
                name="Dólar/Real",
                from_currency="USD",
                to_currency="BRL",
                bid_price=5.1,
                change_percent=0.5,
            ),
            CurrencyQuote(
                pair="EUR-BRL",
                name="Euro/Real",
                from_currency="EUR",
                to_currency="BRL",
                bid_price=6.0,
            ),
        ],
        count=2,
    )

    service = CurrencyService(client=client)
    service.list_pairs = AsyncMock(  # type: ignore[method-assign]
        return_value=CurrencyPairListResponse(
            pairs=[
                CurrencyPairSummary(pair="USD-BRL", name="Dólar/Real"),
                CurrencyPairSummary(pair="EUR-BRL", name="Euro/Real"),
                CurrencyPairSummary(pair="JPY-BRL", name="Iene/Real"),
            ],
            count=3,
        )
    )

    page1 = asyncio.run(service.explore(page=1, limit=2))
    assert page1.total == 3
    assert page1.total_pages == 2
    assert page1.page == 1
    assert len(page1.items) == 2
    assert page1.items[0].pair == "USD-BRL"
    assert page1.items[0].bid_price == 5.1

    page2 = asyncio.run(service.explore(page=2, limit=2))
    assert page2.page == 2
    assert len(page2.items) == 1
    assert page2.items[0].pair == "JPY-BRL"


def test_explore_filters_majors_group():
    service = CurrencyService(client=AsyncMock())
    service.list_pairs = AsyncMock(  # type: ignore[method-assign]
        return_value=CurrencyPairListResponse(
            pairs=[
                CurrencyPairSummary(pair="USD-BRL", name="Dólar/Real"),
                CurrencyPairSummary(pair="EUR-BRL", name="Euro/Real"),
                CurrencyPairSummary(pair="ARS-BRL", name="Peso/Real"),
            ],
            count=3,
        )
    )
    service._client.get_currency_rates = AsyncMock(  # type: ignore[attr-defined]
        return_value=CurrencyListResponse(
            items=[
                CurrencyQuote(
                    pair="USD-BRL",
                    name="Dólar/Real",
                    from_currency="USD",
                    to_currency="BRL",
                ),
                CurrencyQuote(
                    pair="EUR-BRL",
                    name="Euro/Real",
                    from_currency="EUR",
                    to_currency="BRL",
                ),
            ],
            count=2,
        )
    )

    result = asyncio.run(service.explore(group="majors", limit=10))

    assert result.total == 2
    assert {item.pair for item in result.items} == {"USD-BRL", "EUR-BRL"}
