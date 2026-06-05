from __future__ import annotations

from app.config import settings
from app.core.cache import TtlCache
from app.domain.dividends.calendar_universe import BR_DIVIDEND_CALENDAR_TICKERS
from app.services.fii_service import FiiService, fii_service
from app.services.quote_service import QuoteService, quote_service

_CATALOG_TICKERS_TTL = 60 * 60 * 24
_catalog_cache: TtlCache[tuple[str, ...]] = TtlCache(_CATALOG_TICKERS_TTL)


async def load_br_dividend_calendar_tickers(
    *,
    quote_svc: QuoteService | None = None,
    fii_svc: FiiService | None = None,
    max_tickers: int | None = None,
) -> tuple[str, ...]:
    """Universo B3: catálogo de ações, BDRs, ETFs BR e FIIs (cache 24h)."""
    cap = max_tickers if max_tickers is not None else settings.bolsai_calendar_max_tickers
    cache_key = f"b3_div_tickers:{cap}"
    cached = _catalog_cache.get(cache_key)
    if cached is not None:
        return cached

    quotes = quote_svc or quote_service
    fiis = fii_svc or fii_service
    symbols: list[str] = list(BR_DIVIDEND_CALENDAR_TICKERS)

    if settings.bolsai_calendar_include_catalog:
        for category in ("acoes_br", "bdr", "etf"):
            try:
                catalog = await quotes.get_stock_catalog(category)
                symbols.extend(item.symbol for item in catalog.items if item.symbol)
            except Exception:
                continue

    try:
        symbols.extend(await fiis.load_catalog_tickers())
    except Exception:
        pass

    unique = list(dict.fromkeys(s.upper().strip() for s in symbols if s))
    if cap > 0 and len(unique) > cap:
        unique = unique[:cap]

    result = tuple(unique)
    _catalog_cache.set(cache_key, result)
    return result
