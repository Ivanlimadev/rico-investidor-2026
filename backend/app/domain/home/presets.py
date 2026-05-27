FEATURED_FII_TICKERS: tuple[str, ...] = (
    "HGLG11",
    "MXRF11",
    "KNRI11",
    "XPLG11",
    "BCFF11",
    "VISC11",
    "HGRE11",
    "BRCR11",
)

FEATURED_FII_SCREENER_PARAMS: dict[str, str] = {
    "dividend_yield_ttm_gt": "7",
    "dividend_yield_ttm_lt": "16",
    "pvp_lt": "1.05",
    "sort": "dividend_yield_ttm",
    "order": "desc",
    "limit": "8",
}
