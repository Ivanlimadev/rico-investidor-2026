"""Universo de tickers para montar a agenda de dividendos EUA."""

from app.domain.global_markets.presets import FEATURED_US_REITS, FEATURED_US_TICKERS, US_TICKER_NAMES

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
