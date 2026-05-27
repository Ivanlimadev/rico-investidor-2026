from enum import Enum

from app.providers.registry import AssetClass, DataProvider, provider_for


class FiiCapability(str, Enum):
    CORE = "core"
    DIVIDENDS = "dividends"
    HISTORY = "history"
    CANDLES = "candles"
    LIST = "list"
    SCREENER = "screener"
    TENANTS = "tenants"
    TOP_PROPERTIES = "top_properties"


def fii_provider_for(capability: FiiCapability) -> DataProvider:
    return DataProvider.BRAPI


def fii_provider_rules() -> dict[str, str]:
    return {
        capability.value: DataProvider.BRAPI.value
        for capability in FiiCapability
    }


__all__ = [
    "AssetClass",
    "DataProvider",
    "FiiCapability",
    "fii_provider_for",
    "fii_provider_rules",
    "provider_for",
]
