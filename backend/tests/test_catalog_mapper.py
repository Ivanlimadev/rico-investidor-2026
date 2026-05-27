from app.clients.brapi.stock_mapper import map_catalog_item
from app.providers.registry import AssetClass


def test_map_catalog_item_filters_by_target_class():
    stock = map_catalog_item({"stock": "PETR4", "name": "Petrobras", "type": "stock"}, target_class=AssetClass.STOCK_BR)
    etf = map_catalog_item({"stock": "BOVA11", "name": "Ibovespa", "type": "stock"}, target_class=AssetClass.STOCK_BR)
    bova_as_etf = map_catalog_item({"stock": "BOVA11", "name": "Ibovespa", "type": "stock"}, target_class=AssetClass.ETF_BR)

    assert stock is not None
    assert stock.symbol == "PETR4"
    assert etf is None
    assert bova_as_etf is not None
    assert bova_as_etf.category == "etf"
