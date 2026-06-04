"""Mercados expostos no app.

Temporariamente apenas EUA e Brasil. Ao migrar para a nova API global,
reexpandir ``ENABLED_MARKET_COUNTRY_CODES`` e ``ENABLED_EXCHANGE_MICS``.
"""

from __future__ import annotations

from app.core.exceptions import UpstreamError

ENABLED_MARKET_COUNTRY_CODES: tuple[str, ...] = ("US", "BR")

# MICs Marketstack usados em listagens por bolsa.
ENABLED_EXCHANGE_MICS: frozenset[str] = frozenset({"XNAS", "XNYS", "ARCX", "BVMF"})


def is_market_country_enabled(country_code: str) -> bool:
    return country_code.upper().strip() in ENABLED_MARKET_COUNTRY_CODES


def is_exchange_mic_enabled(mic: str) -> bool:
    return mic.upper().strip() in ENABLED_EXCHANGE_MICS


def require_market_country(country_code: str) -> str:
    normalized = country_code.upper().strip()
    if not is_market_country_enabled(normalized):
        raise UpstreamError(
            f"Mercado indisponível no momento: {normalized}. "
            "No app, apenas Estados Unidos e Brasil estão ativos.",
            status_code=404,
        )
    return normalized


def require_exchange_mic(mic: str) -> str:
    normalized = mic.upper().strip()
    if not is_exchange_mic_enabled(normalized):
        raise UpstreamError(
            f"Bolsa indisponível no momento: {normalized}.",
            status_code=404,
        )
    return normalized
