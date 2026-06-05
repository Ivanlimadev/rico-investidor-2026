"""Universo de tickers para montar a agenda (amostra líquida + pagadoras de proventos)."""

from app.domain.global_markets.presets import FEATURED_US_REITS, FEATURED_US_TICKERS, US_TICKER_NAMES
from app.domain.home.presets import FEATURED_FII_TICKERS
from app.domain.quotes.category_map import FEATURED_STOCK_TICKERS

# Ações BR com histórico frequente de proventos (B3).
BR_DIVIDEND_CALENDAR_TICKERS: tuple[str, ...] = tuple(
    dict.fromkeys(
        (
            *FEATURED_STOCK_TICKERS,
            "ITUB3",
            "BBDC3",
            "BBAS3",
            "SANB11",
            "TAEE11",
            "EGIE3",
            "CMIG4",
            "CPLE6",
            "ELET3",
            "ENBR3",
            "VIVT3",
            "SUZB3",
            "KLBN11",
            "CXSE3",
            "TIMS3",
            "GGBR4",
            "CSAN3",
            "RADL3",
            "HAPV3",
            "B3SA3",
            "PRIO3",
            "RAIL3",
            *FEATURED_FII_TICKERS,
            "MXRF11",
            "KNCR11",
            "XPML11",
            "VISC11",
            "BTLG11",
            "XPLG11",
        )
    )
)

US_DIVIDEND_CALENDAR_TICKERS: tuple[str, ...] = tuple(
    dict.fromkeys(
        (
            *FEATURED_US_TICKERS,
            *FEATURED_US_REITS,
            "KO",
            "JNJ",
            "PG",
            "PEP",
            "VZ",
            "T",
            "XOM",
            "CVX",
            "ABBV",
            "MRK",
            "BMY",
            "KMI",
            "OKE",
            "EPD",
            "MAIN",
            "STAG",
        )
    )
)


def us_company_name(symbol: str) -> str:
    return US_TICKER_NAMES.get(symbol.upper(), symbol.upper())
