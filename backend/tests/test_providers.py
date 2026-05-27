from app.providers.fii_providers import FiiCapability, fii_provider_for
from app.providers.registry import AssetClass, DataProvider, provider_for


def test_fii_provider_is_brapi():
    for capability in FiiCapability:
        assert fii_provider_for(capability) == DataProvider.BRAPI


def test_stock_provider_is_brapi():
    assert provider_for(AssetClass.STOCK_BR) == DataProvider.BRAPI
    assert provider_for(AssetClass.ETF_BR) == DataProvider.BRAPI
    assert provider_for(AssetClass.BDR) == DataProvider.BRAPI
    assert provider_for(AssetClass.FII) == DataProvider.BRAPI
