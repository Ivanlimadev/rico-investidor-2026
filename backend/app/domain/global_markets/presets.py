"""Presets de mercados globais — EUA primeiro, Brasil em seguida."""

from app.domain.global_markets.regions import ENABLED_MARKET_COUNTRY_CODES

FEATURED_US_TICKERS: tuple[str, ...] = (
    "AAPL",
    "MSFT",
    "NVDA",
    "GOOGL",
    "AMZN",
    "META",
    "TSLA",
    "SPY",
)

FEATURED_US_REITS: tuple[str, ...] = (
    "O",
    "PLD",
    "AMT",
    "EQIX",
    "SPG",
)

US_MARKET_CATEGORIES: tuple[dict[str, str], ...] = (
    {"slug": "stocks", "label": "Ações EUA", "mic": "XNAS"},
    {"slug": "reits", "label": "REITs", "mic": "XNYS"},
)

US_EXCHANGES: tuple[dict[str, str], ...] = (
    {"mic": "XNAS", "name": "NASDAQ", "country_code": "US", "country_name": "Estados Unidos"},
    {"mic": "XNYS", "name": "NYSE", "country_code": "US", "country_name": "Estados Unidos"},
    {"mic": "ARCX", "name": "NYSE Arca", "country_code": "US", "country_name": "Estados Unidos"},
)

# Segmentos agregados para listagem completa do mercado americano.
US_STOCK_SEGMENTS: tuple[tuple[str, str], ...] = (
    ("XNAS", "NASDAQ"),
    ("XNYS", "NYSE"),
    ("ARCX", "NYSE Arca"),
)

US_REITS_SEGMENTS: tuple[tuple[str, str], ...] = (
    ("XNYS", "NYSE"),
)

BR_EXCHANGES: tuple[dict[str, str], ...] = (
    {"mic": "BVMF", "name": "B3", "country_code": "BR", "country_name": "Brasil"},
)

# Países exibidos no hub (hoje = mercados ativos; ver regions.py).
PRIORITY_COUNTRY_CODES: tuple[str, ...] = ENABLED_MARKET_COUNTRY_CODES

COUNTRY_DISPLAY_NAMES: dict[str, str] = {
    "US": "Estados Unidos",
    "BR": "Brasil",
    "CA": "Canadá",
    "DE": "Alemanha",
    "GB": "Reino Unido",
    "FR": "França",
    "JP": "Japão",
    "HK": "Hong Kong",
    "AU": "Austrália",
    "CH": "Suíça",
    "NL": "Países Baixos",
    "IT": "Itália",
    "ES": "Espanha",
}

# Bolsas principais por país — MICs reais da Marketstack (ex.: XETRA, não XETR).
COUNTRY_EXCHANGE_FALLBACK: dict[str, tuple[tuple[str, str], ...]] = {
    "CA": (("XTSE", "Toronto Stock Exchange"),),
    "DE": (("XETRA", "Deutsche Börse Xetra"), ("XFRA", "Deutsche Börse Frankfurt")),
    "GB": (("XLON", "London Stock Exchange"),),
    "FR": (("XPAR", "Euronext Paris"),),
    "JP": (("XTKS", "Tokyo Stock Exchange"),),
    "HK": (("XHKG", "Hong Kong Stock Exchange"),),
    "AU": (("XASX", "Australian Securities Exchange"),),
    "CH": (("XSWX", "SIX Swiss Exchange"),),
    "NL": (("XAMS", "Euronext Amsterdam"),),
    "IT": (("XMIL", "Borsa Italiana"),),
    "ES": (("XMAD", "Bolsa de Madrid"),),
}


def country_exchange_segments(country_code: str) -> tuple[tuple[str, str], ...]:
    return COUNTRY_EXCHANGE_FALLBACK.get(country_code.upper().strip(), ())


def country_display_name(code: str, fallback: str | None = None) -> str:
    normalized = code.upper().strip()
    return COUNTRY_DISPLAY_NAMES.get(normalized) or fallback or normalized

US_TICKER_NAMES: dict[str, str] = {
    "AAPL": "Apple",
    "MSFT": "Microsoft",
    "NVDA": "NVIDIA",
    "GOOGL": "Alphabet",
    "AMZN": "Amazon",
    "META": "Meta Platforms",
    "TSLA": "Tesla",
    "SPY": "SPDR S&P 500 ETF",
    "O": "Realty Income",
    "PLD": "Prologis",
    "AMT": "American Tower",
    "EQIX": "Equinix",
    "SPG": "Simon Property Group",
}


class CountryHubPreset:
    __slots__ = ("featured", "tech", "dividends")

    def __init__(
        self,
        *,
        featured: tuple[str, ...] = (),
        tech: tuple[str, ...] = (),
        dividends: tuple[str, ...] = (),
    ) -> None:
        self.featured = featured
        self.tech = tech
        self.dividends = dividends


COUNTRY_HUB_PRESETS: dict[str, CountryHubPreset] = {
    "US": CountryHubPreset(
        featured=FEATURED_US_TICKERS,
        tech=("NVDA", "MSFT", "GOOGL", "META", "AMD", "AVGO", "CRM", "PLTR", "INTC", "ORCL"),
        dividends=("KO", "JNJ", "PG", "PEP", "VZ", "T", "XOM"),
    ),
    "CA": CountryHubPreset(
        featured=("RY", "TD", "ENB", "SHOP", "CNQ", "BMO", "CP", "TRI"),
        tech=("SHOP", "CSU", "OTEX", "BB", "LSPD"),
        dividends=("RY", "TD", "ENB", "BCE", "TRP"),
    ),
    "DE": CountryHubPreset(
        featured=("SAP", "SIE", "ALV", "BMW", "MBG", "BAS", "DTE", "ADS"),
        tech=("SAP", "SIE", "IFX", "DB1", "ADS"),
    ),
    "GB": CountryHubPreset(
        featured=("SHEL", "AZN", "HSBA", "ULVR", "BP", "GSK", "RIO", "BATS"),
        tech=("ARM", "SGE", "REL", "EXPN"),
    ),
    "FR": CountryHubPreset(
        featured=("MC", "OR", "SAN", "AI", "TTE", "BNP", "SU", "AIR"),
        tech=("CAP", "DSY", "STM", "ATO"),
    ),
    "JP": CountryHubPreset(
        featured=("TM", "SONY", "MUFG", "SMFG", "MFG", "HMC", "NMR", "TAK", "CAJ"),
        tech=("SONY", "CAJ", "KYOCY", "PCRFY", "NTDOY"),
        dividends=("TM", "MUFG", "SMFG", "MFG", "NMR"),
    ),
    "HK": CountryHubPreset(
        featured=("0700", "9988", "0941", "1299", "0388", "2318", "0005", "3690"),
        tech=("0700", "9988", "3690", "9618", "1810"),
    ),
    "AU": CountryHubPreset(
        featured=("BHP", "CBA", "CSL", "NAB", "WBC", "MQG", "WES", "FMG"),
        tech=("XRO", "WTC", "CPU", "APX"),
    ),
    "BR": CountryHubPreset(
        featured=("PETR4", "VALE3", "ITUB4", "BBDC4", "ABEV3", "WEGE3", "BBAS3", "MGLU3"),
    ),
}


# Países sem dados de bolsa local na Marketstack — usamos os ADRs listados nos EUA.
ADR_BACKED_COUNTRIES: frozenset[str] = frozenset({"JP"})

# Nomes amigáveis para os ADRs (a Marketstack costuma devolver só o símbolo).
ADR_TICKER_NAMES: dict[str, str] = {
    "TM": "Toyota Motor",
    "SONY": "Sony Group",
    "MUFG": "Mitsubishi UFJ Financial",
    "SMFG": "Sumitomo Mitsui Financial",
    "MFG": "Mizuho Financial",
    "HMC": "Honda Motor",
    "NMR": "Nomura Holdings",
    "TAK": "Takeda Pharmaceutical",
    "CAJ": "Canon",
    "KYOCY": "Kyocera",
    "PCRFY": "Panasonic",
    "NTDOY": "Nintendo",
}


def is_adr_backed_country(country_code: str) -> bool:
    return country_code.upper().strip() in ADR_BACKED_COUNTRIES


def adr_ticker_name(symbol: str) -> str | None:
    return ADR_TICKER_NAMES.get(symbol.upper().strip())


def country_hub_preset(country_code: str) -> CountryHubPreset:
    return COUNTRY_HUB_PRESETS.get(country_code.upper().strip(), CountryHubPreset())
