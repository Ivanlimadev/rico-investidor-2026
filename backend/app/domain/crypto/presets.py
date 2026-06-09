"""Criptomoedas spot USDT na Binance — exibição em USD."""

FEATURED_CRYPTO_SYMBOLS: tuple[str, ...] = (
    "BTC",
    "ETH",
    "SOL",
    "BNB",
    "XRP",
    "ADA",
    "DOGE",
    "DOT",
    "AVAX",
    "LINK",
    "MATIC",
    "POL",
    "LTC",
    "UNI",
    "ATOM",
    "NEAR",
    "APT",
    "SUI",
    "PEPE",
    "SHIB",
)

# IDs CoinGecko para gráficos/histórico quando a Binance estiver indisponível (451).
COINGECKO_COIN_IDS: dict[str, str] = {
    "BTC": "bitcoin",
    "ETH": "ethereum",
    "SOL": "solana",
    "BNB": "binancecoin",
    "XRP": "ripple",
    "ADA": "cardano",
    "DOGE": "dogecoin",
    "DOT": "polkadot",
    "AVAX": "avalanche-2",
    "LINK": "chainlink",
    "MATIC": "matic-network",
    "POL": "polygon-ecosystem-token",
    "LTC": "litecoin",
    "UNI": "uniswap",
    "ATOM": "cosmos",
    "NEAR": "near",
    "APT": "aptos",
    "SUI": "sui",
    "PEPE": "pepe",
    "SHIB": "shiba-inu",
    "AAVE": "aave",
    "ARB": "arbitrum",
    "OP": "optimism",
    "INJ": "injective-protocol",
    "TRX": "tron",
    "BCH": "bitcoin-cash",
    "XLM": "stellar",
    "ETC": "ethereum-classic",
    "HBAR": "hedera-hashgraph",
    "FIL": "filecoin",
    "ICP": "internet-computer",
}

CRYPTO_NAMES: dict[str, str] = {
    "BTC": "Bitcoin",
    "ETH": "Ethereum",
    "SOL": "Solana",
    "BNB": "BNB",
    "XRP": "XRP",
    "ADA": "Cardano",
    "DOGE": "Dogecoin",
    "DOT": "Polkadot",
    "AVAX": "Avalanche",
    "LINK": "Chainlink",
    "MATIC": "Polygon",
    "POL": "Polygon",
    "LTC": "Litecoin",
    "UNI": "Uniswap",
    "ATOM": "Cosmos",
    "NEAR": "NEAR Protocol",
    "APT": "Aptos",
    "SUI": "Sui",
    "PEPE": "Pepe",
    "SHIB": "Shiba Inu",
    "AAVE": "Aave",
    "ARB": "Arbitrum",
    "OP": "Optimism",
    "INJ": "Injective",
    "FET": "Fetch.ai",
    "RENDER": "Render",
    "FIL": "Filecoin",
    "ICP": "Internet Computer",
    "BCH": "Bitcoin Cash",
    "TRX": "TRON",
    "XLM": "Stellar",
    "ETC": "Ethereum Classic",
    "HBAR": "Hedera",
    "VET": "VeChain",
    "ALGO": "Algorand",
    "FLOKI": "Floki",
    "WIF": "dogwifhat",
    "BONK": "Bonk",
    "CRV": "Curve",
    "MKR": "Maker",
    "LDO": "Lido DAO",
    "USDC": "USD Coin",
}

CRYPTO_EXPLORE_GROUPS: dict[str, tuple[str, ...] | None] = {
    "all": None,
    "major": (
        "BTC",
        "ETH",
        "BNB",
        "SOL",
        "XRP",
        "ADA",
        "DOGE",
        "DOT",
        "AVAX",
        "LINK",
        "POL",
        "MATIC",
        "LTC",
        "UNI",
        "ATOM",
        "NEAR",
        "TRX",
        "BCH",
    ),
    "defi": ("UNI", "AAVE", "LINK", "MKR", "CRV", "LDO", "SNX", "COMP", "SUSHI"),
    "meme": ("DOGE", "SHIB", "PEPE", "FLOKI", "WIF", "BONK"),
}

QUOTE_ASSET = "USDT"
DISPLAY_CURRENCY = "USD"

MOVER_STABLECOINS: frozenset[str] = frozenset(
    {"USDT", "USDC", "FDUSD", "TUSD", "USDP", "DAI", "EUR", "AEUR", "BUSD"}
)
MIN_MOVER_QUOTE_VOLUME_USDT = 500_000
DEFAULT_MOVER_LIMIT = 5
MAX_MOVER_LIMIT = 10
DEFAULT_HEATMAP_LIMIT = 18
MAX_HEATMAP_LIMIT = 24

VALID_KLINE_INTERVALS: frozenset[str] = frozenset({"1m", "5m", "15m", "1h", "4h", "1d", "1w"})

# preset_id -> (interval, limit)
CRYPTO_CHART_PRESETS: dict[str, tuple[str, int]] = {
    "1d": ("1h", 24),
    "1w": ("4h", 42),
    "1m": ("1d", 30),
    "3m": ("1d", 90),
    "1y": ("1d", 365),
    # Semanal: até ~19 anos em 1 request (limite Binance 1000 klines). Diário em 1000
    # dias distorce o "MAX" vs gráficos de corretora.
    "max": ("1w", 1000),
}
