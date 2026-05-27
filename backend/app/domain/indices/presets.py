"""Catálogo de índices disponíveis via Brapi /quote."""

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class IndexPreset:
    symbol: str
    name: str
    group: str


INDEX_CATALOG: tuple[IndexPreset, ...] = (
    IndexPreset("^BVSP", "Ibovespa", "brasil"),
    IndexPreset("^IBRX", "IBrX-100", "brasil"),
    IndexPreset("^IBXX", "IBrX-50", "brasil"),
    IndexPreset("IFIX", "IFIX", "fiis"),
    IndexPreset("IDIV", "IDIV", "brasil"),
    IndexPreset("SMLL", "Small Cap (B3)", "brasil"),
    IndexPreset("IFNC", "Índice Financeiro", "setorial"),
    IndexPreset("IMAT", "Índice de Materiais Básicos", "setorial"),
    IndexPreset("INDX", "Índice Industrial", "setorial"),
    IndexPreset("IMOB", "Índice Imobiliário", "setorial"),
    IndexPreset("ICON", "Índice de Consumo", "setorial"),
    IndexPreset("IEE", "Índice de Energia Elétrica", "setorial"),
    IndexPreset("UTIL", "Índice de Utilidade Pública", "setorial"),
    IndexPreset("^GSPC", "S&P 500", "internacional"),
    IndexPreset("^IXIC", "Nasdaq Composite", "internacional"),
    IndexPreset("^DJI", "Dow Jones", "internacional"),
    IndexPreset("^NDX", "Nasdaq 100", "internacional"),
    IndexPreset("^RUT", "Russell 2000", "internacional"),
    IndexPreset("^FTSE", "FTSE 100", "internacional"),
    IndexPreset("^N225", "Nikkei 225", "internacional"),
    IndexPreset("^STOXX50E", "Euro Stoxx 50", "internacional"),
)

FEATURED_INDEX_SYMBOLS: tuple[str, ...] = (
    "^BVSP",
    "IFIX",
    "^IBRX",
    "IDIV",
    "^GSPC",
    "^IXIC",
)

INDEX_EXPLORE_GROUPS: dict[str, str | None] = {
    "all": None,
    "brasil": "brasil",
    "fiis": "fiis",
    "setorial": "setorial",
    "internacional": "internacional",
}

INDEX_BY_SYMBOL: dict[str, IndexPreset] = {item.symbol.upper(): item for item in INDEX_CATALOG}
