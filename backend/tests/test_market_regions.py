import asyncio
from unittest.mock import AsyncMock

import pytest

from app.core.exceptions import UpstreamError
from app.domain.global_markets.regions import (
    is_exchange_mic_enabled,
    is_market_country_enabled,
    require_exchange_mic,
    require_market_country,
)
from app.domain.global_markets.models import ExchangeInfo
from app.services.global_market_service import GlobalMarketService


def test_enabled_countries_are_us_and_br_only():
    assert is_market_country_enabled("US")
    assert is_market_country_enabled("br")
    assert not is_market_country_enabled("DE")
    assert not is_market_country_enabled("JP")


def test_enabled_exchange_mics():
    assert is_exchange_mic_enabled("XNAS")
    assert is_exchange_mic_enabled("BVMF")
    assert not is_exchange_mic_enabled("XETRA")


def test_require_market_country_rejects_disabled():
    with pytest.raises(UpstreamError) as exc:
        require_market_country("DE")
    assert exc.value.status_code == 404


def test_list_world_exchanges_filters_to_us_br():
    client = AsyncMock()
    client.map_exchanges.return_value = [
        ExchangeInfo(mic="XNAS", name="NASDAQ", country="USA", country_code="US"),
        ExchangeInfo(mic="BVMF", name="B3", country="Brazil", country_code="BR"),
        ExchangeInfo(mic="XETRA", name="Xetra", country="Germany", country_code="DE"),
    ]

    service = GlobalMarketService(client=client)
    result = asyncio.run(service.list_world_exchanges())

    codes = {group.country_code for group in result.priority_countries + result.other_countries}
    assert codes == {"US", "BR"}
    assert result.total_countries == 2


def test_get_country_hub_rejects_disabled_country():
    service = GlobalMarketService(client=AsyncMock())
    with pytest.raises(UpstreamError) as exc:
        asyncio.run(service.get_country_hub("DE"))
    assert exc.value.status_code == 404
