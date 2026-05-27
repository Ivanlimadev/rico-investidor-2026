from enum import Enum


class AssetClass(str, Enum):
    FII = "fii"
    STOCK_BR = "stock_br"
    ETF_BR = "etf_br"
    BDR = "bdr"
    STOCK_US = "stock_us"
    CRYPTO = "crypto"


class DataProvider(str, Enum):
    BRAPI = "brapi"
    POLYGON = "polygon"


def provider_for(asset_class: AssetClass) -> DataProvider:
    if asset_class == AssetClass.FII:
        return DataProvider.BRAPI
    if asset_class in {
        AssetClass.STOCK_BR,
        AssetClass.ETF_BR,
        AssetClass.BDR,
    }:
        return DataProvider.BRAPI
    raise NotImplementedError(
        f"Provedor ainda não configurado para {asset_class.value}."
    )
