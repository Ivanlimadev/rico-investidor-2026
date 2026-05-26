from app.domain.fii.ticker import is_valid_fii_ticker, normalize_fii_ticker
from app.domain.quotes.category_map import looks_like_fii
from app.providers.registry import AssetClass


def normalize_asset_ticker(raw: str) -> str:
    cleaned = raw.strip().upper().replace(".SA", "")
    if is_valid_fii_ticker(cleaned) and looks_like_fii(normalize_fii_ticker(cleaned)):
        return normalize_fii_ticker(cleaned)
    return cleaned


def resolve_asset_class(ticker: str) -> AssetClass:
    normalized = normalize_asset_ticker(ticker)

    if is_valid_fii_ticker(normalized) and looks_like_fii(normalized):
        return AssetClass.FII
    if normalized.endswith("34"):
        return AssetClass.BDR
    if normalized.endswith("11") and not looks_like_fii(normalized):
        return AssetClass.ETF_BR
    return AssetClass.STOCK_BR
