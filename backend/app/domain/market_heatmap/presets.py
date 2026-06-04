"""Presets compartilhados para mapas de calor de ações."""

DEFAULT_HEATMAP_LIMIT = 18
MAX_HEATMAP_LIMIT = 24

# Bolsa principal EUA — NASDAQ (MIC XNAS).
US_PRIMARY_EXCHANGE_MIC = "XNAS"

# Volume mínimo do pregão para entrar no mapa (evita microcaps sem liquidez).
MIN_BR_STOCK_HEATMAP_VOLUME = 500_000
MIN_US_STOCK_HEATMAP_VOLUME = 100_000

# Símbolos por requisição EOD na Marketstack (heatmap usa lote único).
US_HEATMAP_EOD_BATCH_SIZE = 40

# Candidatos líquidos NASDAQ — rankeados localmente por volume EOD.
US_NASDAQ_HEATMAP_CANDIDATES: tuple[str, ...] = (
    "AAPL",
    "MSFT",
    "NVDA",
    "GOOGL",
    "GOOG",
    "AMZN",
    "META",
    "TSLA",
    "AVGO",
    "COST",
    "NFLX",
    "AMD",
    "PEP",
    "ADBE",
    "CSCO",
    "INTC",
    "CMCSA",
    "TXN",
    "QCOM",
    "INTU",
    "AMGN",
    "HON",
    "AMAT",
    "BKNG",
    "ISRG",
    "VRTX",
    "ADP",
    "SBUX",
    "GILD",
    "MU",
    "PANW",
    "LRCX",
    "ADI",
    "REGN",
    "MDLZ",
    "KLAC",
    "SNPS",
    "CDNS",
    "CRWD",
    "MAR",
)
