from enum import Enum


class AssetClass(str, Enum):
    STOCK_US = "stock_us"
    CRYPTO = "crypto"


class DataProvider(str, Enum):
    MARKETSTACK = "marketstack"
    POLYGON = "polygon"


def provider_for(asset_class: AssetClass) -> DataProvider:
    if asset_class == AssetClass.STOCK_US:
        return DataProvider.MARKETSTACK
    raise NotImplementedError(
        f"Provedor ainda não configurado para {asset_class.value}."
    )
