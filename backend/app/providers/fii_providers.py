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


_BOLSAI_CAPABILITIES = {
    FiiCapability.SCREENER,
    FiiCapability.TENANTS,
    FiiCapability.TOP_PROPERTIES,
}


def fii_provider_for(capability: FiiCapability) -> DataProvider:
    if capability in _BOLSAI_CAPABILITIES:
        return DataProvider.BOLSAI
    return DataProvider.BRAPI


def fii_provider_rules() -> dict[str, str]:
    return {
        capability.value: fii_provider_for(capability).value
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
