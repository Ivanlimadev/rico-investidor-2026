from app.domain.quotes.category_map import infer_category
from app.providers.fii_providers import FiiCapability, fii_provider_for
from app.providers.registry import AssetClass, DataProvider, provider_for


def test_fii_dual_providers():
    assert fii_provider_for(FiiCapability.CORE) == DataProvider.BRAPI
    assert fii_provider_for(FiiCapability.DIVIDENDS) == DataProvider.BRAPI
    assert fii_provider_for(FiiCapability.TENANTS) == DataProvider.BOLSAI
    assert fii_provider_for(FiiCapability.TOP_PROPERTIES) == DataProvider.BOLSAI
    assert fii_provider_for(FiiCapability.SCREENER) == DataProvider.BOLSAI


def test_stock_provider_is_brapi():
    assert provider_for(AssetClass.STOCK_BR) == DataProvider.BRAPI
    assert provider_for(AssetClass.ETF_BR) == DataProvider.BRAPI
    assert provider_for(AssetClass.BDR) == DataProvider.BRAPI
    assert provider_for(AssetClass.FII) == DataProvider.BRAPI


def test_infer_category():
    assert infer_category("PETR4", "stock") == AssetClass.STOCK_BR
    assert infer_category("AAPL34", "bdr") == AssetClass.BDR
    assert infer_category("HGLG11", "fund") == AssetClass.FII
    assert infer_category("BOVA11", "stock") == AssetClass.ETF_BR
