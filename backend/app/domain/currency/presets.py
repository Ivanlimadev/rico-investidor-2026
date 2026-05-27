"""Pares de câmbio exibidos por padrão no app (contra BRL)."""

FEATURED_CURRENCY_PAIRS: tuple[str, ...] = (
    "USD-BRL",
    "EUR-BRL",
    "GBP-BRL",
    "JPY-BRL",
    "CHF-BRL",
    "CAD-BRL",
    "AUD-BRL",
    "CNY-BRL",
    "ARS-BRL",
    "MXN-BRL",
    "CLP-BRL",
    "NOK-BRL",
    "SEK-BRL",
    "DKK-BRL",
    "NZD-BRL",
    "HKD-BRL",
    "SGD-BRL",
    "ZAR-BRL",
    "TRY-BRL",
    "INR-BRL",
)

CURRENCY_EXPLORE_GROUPS: dict[str, tuple[str, ...] | None] = {
    "all": None,
    "majors": ("USD", "EUR", "GBP", "CHF", "JPY", "CAD", "AUD", "NZD"),
    "americas": ("USD", "CAD", "MXN", "CLP", "ARS", "COP", "PEN", "UYU"),
    "europe": ("EUR", "GBP", "CHF", "NOK", "SEK", "DKK", "PLN", "CZK", "HUF", "RUB"),
    "asia": ("JPY", "CNY", "HKD", "SGD", "KRW", "INR", "THB", "TWD", "IDR", "ILS"),
}
