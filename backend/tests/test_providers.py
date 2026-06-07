from app.providers.registry import AssetClass, DataProvider, provider_for


def test_stock_us_provider_is_marketstack():
    assert provider_for(AssetClass.STOCK_US) == DataProvider.MARKETSTACK
