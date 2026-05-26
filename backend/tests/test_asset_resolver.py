from app.domain.assets.resolver import normalize_asset_ticker, resolve_asset_class
from app.providers.registry import AssetClass


def test_resolve_stock():
    assert resolve_asset_class("PETR4") == AssetClass.STOCK_BR
    assert normalize_asset_ticker("petr4") == "PETR4"


def test_resolve_bdr():
    assert resolve_asset_class("AAPL34") == AssetClass.BDR


def test_resolve_etf_not_fii():
    assert resolve_asset_class("BOVA11") == AssetClass.ETF_BR


def test_resolve_fii():
    assert resolve_asset_class("MXRF11") == AssetClass.FII
    assert resolve_asset_class("hglg") == AssetClass.FII
    assert normalize_asset_ticker("hglg") == "HGLG11"
