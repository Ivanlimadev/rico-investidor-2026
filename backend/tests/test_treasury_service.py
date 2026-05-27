import asyncio
from unittest.mock import AsyncMock

from app.domain.treasury.models import TreasuryBond, TreasuryListResponse
from app.services.treasury_service import TreasuryService


def test_explore_returns_paginated_bonds():
    client = AsyncMock()
    service = TreasuryService(client=client)
    service._client.get_treasury_list = AsyncMock(  # type: ignore[method-assign]
        return_value=TreasuryListResponse(
            items=[
                TreasuryBond(
                    symbol="tesouro-selic-01032031",
                    bond_type="Tesouro Selic",
                    indexer="selic",
                    sell_price=18989.29,
                )
            ],
            count=1,
            total=10,
            page=1,
            total_pages=2,
            group="selic",
        )
    )

    result = asyncio.run(service.explore(group="selic", page=1, limit=30))

    assert result.total == 10
    assert result.items[0].symbol == "tesouro-selic-01032031"
    service._client.get_treasury_list.assert_awaited_once()


def test_list_featured_uses_indicators():
    client = AsyncMock()
    client.get_treasury_indicators = AsyncMock(
        return_value=[
            TreasuryBond(
                symbol="tesouro-selic-01032031",
                bond_type="Tesouro Selic",
                indexer="selic",
            )
        ]
    )
    service = TreasuryService(client=client)

    bonds = asyncio.run(service.list_featured())

    assert len(bonds) == 1
    assert bonds[0].symbol == "tesouro-selic-01032031"
