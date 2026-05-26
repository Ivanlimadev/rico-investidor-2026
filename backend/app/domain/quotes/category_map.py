"""Mapeamento Brapi → categorias do app."""

from app.providers.registry import AssetClass

# Parâmetro `type` do /api/quote/list
BRAPI_LIST_TYPE: dict[AssetClass, str] = {
    AssetClass.STOCK_BR: "stock",
    AssetClass.BDR: "bdr",
    AssetClass.ETF_BR: "stock",
}

# Slug usado na API pública do backend
CATEGORY_SLUGS: dict[str, AssetClass] = {
    "acoes_br": AssetClass.STOCK_BR,
    "bdr": AssetClass.BDR,
    "etf": AssetClass.ETF_BR,
}

FEATURED_STOCK_TICKERS = ("PETR4", "VALE3", "ITUB4", "MGLU3")


def infer_category(symbol: str, brapi_type: str | None) -> AssetClass:
    normalized = symbol.upper().strip()
    kind = (brapi_type or "").lower()

    if kind == "fund" or (normalized.endswith("11") and _looks_like_fii(normalized)):
        return AssetClass.FII
    if kind == "bdr" or normalized.endswith("34"):
        return AssetClass.BDR
    if normalized.endswith("11") and kind == "stock":
        return AssetClass.ETF_BR
    return AssetClass.STOCK_BR


def category_to_slug(asset_class: AssetClass) -> str:
    return {
        AssetClass.STOCK_BR: "acoes_br",
        AssetClass.BDR: "bdr",
        AssetClass.ETF_BR: "etf",
        AssetClass.FII: "fiis",
    }.get(asset_class, "acoes_br")


def looks_like_fii(symbol: str) -> bool:
    """Heurística: tickers FII terminam em 11; ETFs também — BDR em 34."""
    if symbol.endswith("34"):
        return False
    etf_prefixes = ("BOVA", "SMAL", "IVVB", "BOVV", "DIVO", "FIND", "MATB", "XBOV")
    if symbol.endswith("11") and symbol.startswith(etf_prefixes):
        return False
    return symbol.endswith("11")


def _looks_like_fii(symbol: str) -> bool:
    return looks_like_fii(symbol)
