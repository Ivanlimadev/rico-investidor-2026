"""Grupos de pares por tema — usado em ativos relacionados (detalhe)."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class PeerGroup:
    id: str
    label: str
    symbols: tuple[str, ...]


PEER_GROUPS: dict[str, PeerGroup] = {
    # —— Brasil (B3) ——
    "br_banks": PeerGroup(
        "br_banks",
        "Bancos",
        ("ITUB4", "ITSA4", "BBDC4", "SANB11", "BBAS3", "BPAC11", "BRSR6", "ABCB4", "NUBR33"),
    ),
    "br_oil_gas": PeerGroup(
        "br_oil_gas",
        "Petróleo e gás",
        ("PETR4", "PETR3", "PRIO3", "RRRP3", "UGPA3", "VBBR3", "RADL3"),
    ),
    "br_mining": PeerGroup(
        "br_mining",
        "Mineração e siderurgia",
        ("VALE3", "CSNA3", "GGBR4", "USIM5", "GOAU4", "CMIN3"),
    ),
    "br_utilities": PeerGroup(
        "br_utilities",
        "Elétricas e saneamento",
        ("ELET3", "ELET6", "CPFE3", "ENBR3", "EGIE3", "SBSP3", "TRPL4"),
    ),
    "br_retail": PeerGroup(
        "br_retail",
        "Varejo",
        ("MGLU3", "LREN3", "AMER3", "PETZ3", "CEAB3", "VIVA3"),
    ),
    "br_telecom": PeerGroup(
        "br_telecom",
        "Telecom",
        ("VIVT3", "TIMS3", "OIBR3"),
    ),
    "br_food_bev": PeerGroup(
        "br_food_bev",
        "Alimentos e bebidas",
        ("ABEV3", "JBSS3", "BRFS3", "MDIA3", "PCAR3"),
    ),
    "br_insurance": PeerGroup(
        "br_insurance",
        "Seguros",
        ("BBSE3", "PSSA3", "CXSE3", "WIZC3"),
    ),
    "br_airlines": PeerGroup(
        "br_airlines",
        "Aviação",
        ("AZUL4", "GOLL4", "EMBR3"),
    ),
    # —— EUA ——
    "us_mag7": PeerGroup(
        "us_mag7",
        "Big Tech",
        ("AAPL", "MSFT", "GOOGL", "AMZN", "META", "NVDA", "TSLA"),
    ),
    "us_semiconductors": PeerGroup(
        "us_semiconductors",
        "Semicondutores",
        ("NVDA", "AMD", "INTC", "AVGO", "QCOM", "MU", "AMAT", "LRCX", "TXN", "MRVL"),
    ),
    "us_ai_chips": PeerGroup(
        "us_ai_chips",
        "Chips e IA",
        ("NVDA", "AMD", "AVGO", "MRVL", "ARM", "SMCI", "TSM"),
    ),
    "us_banks": PeerGroup(
        "us_banks",
        "Bancos EUA",
        ("JPM", "BAC", "WFC", "C", "GS", "MS", "USB", "PNC"),
    ),
    "us_cloud_software": PeerGroup(
        "us_cloud_software",
        "Cloud e software",
        ("MSFT", "CRM", "NOW", "ORCL", "ADBE", "SNOW", "PANW"),
    ),
    "us_consumer_tech": PeerGroup(
        "us_consumer_tech",
        "Tecnologia consumo",
        ("AAPL", "AMZN", "NFLX", "DIS", "UBER", "ABNB"),
    ),
    "us_auto": PeerGroup(
        "us_auto",
        "Automotivo",
        ("TSLA", "F", "GM", "RIVN", "LCID", "TM"),
    ),
    "us_pharma": PeerGroup(
        "us_pharma",
        "Farmacêuticas",
        ("JNJ", "PFE", "MRK", "LLY", "ABBV", "BMY"),
    ),
    "us_reits": PeerGroup(
        "us_reits",
        "REITs",
        ("O", "PLD", "AMT", "EQIX", "SPG", "AVB", "DLR"),
    ),
    "us_energy": PeerGroup(
        "us_energy",
        "Energia",
        ("XOM", "CVX", "COP", "SLB", "EOG", "OXY"),
    ),
    # —— Cripto ——
    "crypto_major": PeerGroup(
        "crypto_major",
        "Principais",
        ("BTC", "ETH", "BNB", "SOL", "XRP", "ADA", "DOGE"),
    ),
    "crypto_layer1": PeerGroup(
        "crypto_layer1",
        "Layer 1",
        ("BTC", "ETH", "SOL", "ADA", "AVAX", "DOT", "ATOM", "NEAR", "APT", "SUI"),
    ),
    "crypto_defi": PeerGroup(
        "crypto_defi",
        "DeFi",
        ("UNI", "AAVE", "LINK", "MKR", "CRV", "LDO"),
    ),
    "crypto_meme": PeerGroup(
        "crypto_meme",
        "Meme coins",
        ("DOGE", "SHIB", "PEPE", "FLOKI", "WIF", "BONK"),
    ),
}

TICKER_TO_GROUPS: dict[str, tuple[str, ...]] = {
    # BR — bancos
    "ITUB4": ("br_banks",),
    "ITSA4": ("br_banks",),
    "BBDC4": ("br_banks",),
    "SANB11": ("br_banks",),
    "BBAS3": ("br_banks",),
    "BPAC11": ("br_banks",),
    "BRSR6": ("br_banks",),
    "ABCB4": ("br_banks",),
    "NUBR33": ("br_banks",),
    # BR — petróleo
    "PETR4": ("br_oil_gas",),
    "PETR3": ("br_oil_gas",),
    "PRIO3": ("br_oil_gas",),
    "RRRP3": ("br_oil_gas",),
    # BR — mineração
    "VALE3": ("br_mining",),
    "CSNA3": ("br_mining",),
    "GGBR4": ("br_mining",),
    # US — tech / chips
    "NVDA": ("us_ai_chips", "us_semiconductors", "us_mag7"),
    "AMD": ("us_ai_chips", "us_semiconductors"),
    "INTC": ("us_semiconductors",),
    "AVGO": ("us_ai_chips", "us_semiconductors"),
    "AAPL": ("us_mag7", "us_consumer_tech"),
    "MSFT": ("us_mag7", "us_cloud_software"),
    "GOOGL": ("us_mag7",),
    "AMZN": ("us_mag7", "us_consumer_tech"),
    "META": ("us_mag7",),
    "TSLA": ("us_mag7", "us_auto"),
    # US — bancos
    "JPM": ("us_banks",),
    "BAC": ("us_banks",),
    "WFC": ("us_banks",),
    "GS": ("us_banks",),
    # Crypto
    "BTC": ("crypto_major", "crypto_layer1"),
    "ETH": ("crypto_major", "crypto_layer1"),
    "SOL": ("crypto_layer1", "crypto_major"),
    "DOGE": ("crypto_meme", "crypto_major"),
    "SHIB": ("crypto_meme",),
    "PEPE": ("crypto_meme",),
    "UNI": ("crypto_defi",),
    "AAVE": ("crypto_defi",),
    "LINK": ("crypto_defi",),
}

SECTOR_TO_GROUPS: dict[str, tuple[str, ...]] = {
    "financeiro": ("br_banks",),
    "financials": ("br_banks", "us_banks"),
    "bancos": ("br_banks",),
    "petroleo": ("br_oil_gas",),
    "petróleo": ("br_oil_gas",),
    "gas": ("br_oil_gas",),
    "oil": ("br_oil_gas", "us_energy"),
    "materiais basicos": ("br_mining",),
    "materiais básicos": ("br_mining",),
    "basic materials": ("br_mining",),
    "utilidade publica": ("br_utilities",),
    "utilidades": ("br_utilities",),
    "utilities": ("br_utilities",),
    "consumo ciclico": ("br_retail", "us_auto"),
    "consumo cíclico": ("br_retail", "us_auto"),
    "consumer cyclical": ("br_retail", "us_auto"),
    "consumo nao ciclico": ("br_food_bev",),
    "consumo não cíclico": ("br_food_bev",),
    "consumer defensive": ("br_food_bev", "us_pharma"),
    "tecnologia": ("us_mag7", "us_semiconductors"),
    "technology": ("us_mag7", "us_semiconductors", "us_cloud_software"),
    "communications": ("br_telecom", "us_consumer_tech"),
    "comunicações": ("br_telecom",),
    "real estate": ("us_reits",),
    "seguros": ("br_insurance",),
}

INDUSTRY_TO_GROUPS: dict[str, tuple[str, ...]] = {
    "semiconductors": ("us_semiconductors", "us_ai_chips"),
    "banks": ("us_banks", "br_banks"),
    "banks - regional": ("us_banks",),
    "software": ("us_cloud_software",),
    "internet content": ("us_consumer_tech",),
    "auto manufacturers": ("us_auto",),
    "drug manufacturers": ("us_pharma",),
    "oil & gas": ("us_energy", "br_oil_gas"),
}
