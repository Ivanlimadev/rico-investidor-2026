from __future__ import annotations

from collections.abc import Iterable
from datetime import UTC, datetime, timedelta

from app.clients.brapi.models import MarketQuote
from app.domain.global_markets.models import (
    ExchangeInfo,
    GlobalStockCandle,
    GlobalStockDividend,
    GlobalStockSplit,
    GlobalStockTickerInfo,
)
from app.domain.global_markets.presets import US_TICKER_NAMES


def _safe_float(value: object) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _parse_date(value: object) -> datetime | None:
    if not value:
        return None
    text = str(value)
    try:
        if text.endswith("Z"):
            text = text[:-1] + "+00:00"
        return datetime.fromisoformat(text)
    except ValueError:
        return None


def _change_percent(current: float, previous: float | None) -> float:
    if previous is None or previous == 0:
        return 0.0
    return round(((current - previous) / previous) * 100, 4)


def map_ticker_symbol(item: dict) -> str | None:
    symbol = str(item.get("symbol") or item.get("ticker") or "").upper().strip()
    return symbol or None


def normalize_marketstack_symbol(raw: str) -> str:
    """Marketstack V1: classes US (BRK.B → BRK-B); listagens internacionais mantêm ponto (SAP.XETRA)."""
    upper = raw.upper().strip()
    if "." not in upper:
        return upper
    base, suffix = upper.rsplit(".", 1)
    if len(suffix) == 1 and suffix.isalpha():
        return f"{base}-{suffix}"
    return upper


def is_us_listing_mic(mic: str | None) -> bool:
    return (mic or "").upper() in {"XNAS", "XNYS", "ARCX"}


def qualify_listing_symbol(symbol: str, exchange_mic: str | None) -> str:
    """Qualifica ticker internacional com sufixo da bolsa (RY → RY.XTSE)."""
    upper = symbol.upper().strip()
    if not upper or is_us_listing_mic(exchange_mic):
        return normalize_marketstack_symbol(upper)
    if "." in upper:
        return normalize_marketstack_symbol(upper)
    mic = (exchange_mic or "").upper().strip()
    if not mic:
        return normalize_marketstack_symbol(upper)
    return f"{upper}.{mic}"


def qualify_listing_symbols(symbols: list[str], exchange_mic: str | None) -> list[str]:
    return [qualify_listing_symbol(symbol, exchange_mic) for symbol in symbols if symbol.strip()]


def resolve_catalog_symbol(api_symbol: str, catalog_symbols: list[str]) -> str:
    api_norm = normalize_marketstack_symbol(api_symbol)
    for catalog in catalog_symbols:
        if normalize_marketstack_symbol(catalog) == api_norm:
            return catalog.upper().strip()
    return api_symbol.upper().strip()


def map_ticker_name(item: dict, *, symbol: str) -> str:
    for key in ("name", "stock_name", "company_name"):
        raw = item.get(key)
        if isinstance(raw, str) and raw.strip():
            return raw.strip()
    return US_TICKER_NAMES.get(symbol.upper(), symbol.upper())


def _resolve_name(symbol: str, item: dict) -> str:
    return map_ticker_name(item, symbol=symbol)


def _session_date(item: dict) -> str | None:
    parsed = _parse_date(item.get("date"))
    if parsed:
        return parsed.date().isoformat()
    raw = item.get("date")
    if not raw:
        return None
    text = str(raw)
    return text[:10] if len(text) >= 10 else text


def map_eod_quote(
    item: dict,
    *,
    category: str,
    previous_close: float | None = None,
    name: str | None = None,
) -> MarketQuote | None:
    symbol = str(item.get("symbol") or "").upper().strip()
    close = _safe_float(item.get("close") or item.get("adj_close") or item.get("last"))
    if not symbol or close is None:
        return None

    return MarketQuote(
        symbol=symbol,
        name=name or _resolve_name(symbol, item),
        price=close,
        change_percent=_change_percent(close, previous_close),
        category=category,
        provider="marketstack",
        exchange=str(item.get("exchange") or "").upper().strip() or None,
        open=_safe_float(item.get("open") or item.get("adj_open")),
        high=_safe_float(item.get("high") or item.get("adj_high")),
        low=_safe_float(item.get("low") or item.get("adj_low")),
        volume=_safe_float(item.get("volume") or item.get("adj_volume")),
        previous_close=previous_close,
        session_date=_session_date(item),
        split_factor=_safe_float(item.get("split_factor")),
        dividend_amount=_safe_float(item.get("dividend")),
        adj_close=_safe_float(item.get("adj_close")),
    )


def map_ticker_info(item: dict) -> GlobalStockTickerInfo | None:
    symbol = str(item.get("symbol") or "").upper().strip()
    if not symbol:
        return None
    exchange = item.get("stock_exchange") if isinstance(item.get("stock_exchange"), dict) else {}
    return GlobalStockTickerInfo(
        symbol=symbol,
        name=map_ticker_name(item, symbol=symbol),
        country=str(item.get("country") or "").strip() or None,
        has_eod=bool(item.get("has_eod", True)),
        has_intraday=bool(item.get("has_intraday", False)),
        exchange_mic=str(exchange.get("mic") or "").upper().strip() or None,
        exchange_name=str(exchange.get("name") or "").strip() or None,
        exchange_acronym=str(exchange.get("acronym") or "").strip() or None,
        exchange_city=str(exchange.get("city") or "").strip() or None,
        exchange_country_code=str(exchange.get("country_code") or "").upper().strip() or None,
        exchange_website=str(exchange.get("website") or "").strip() or None,
        isin=str(item.get("isin") or "").strip() or None,
        cusip=str(item.get("cusip") or "").strip() or None,
    )


def map_dividends(items: Iterable[dict]) -> list[GlobalStockDividend]:
    rows: list[GlobalStockDividend] = []
    for item in items:
        amount = _safe_float(item.get("dividend") or item.get("amount"))
        date = str(item.get("date") or "").strip()
        if amount is None or not date:
            continue
        rows.append(GlobalStockDividend(date=date, amount=amount))
    return rows


def map_splits(items: Iterable[dict]) -> list[GlobalStockSplit]:
    rows: list[GlobalStockSplit] = []
    for item in items:
        factor = _safe_float(item.get("split_factor") or item.get("factor"))
        date = str(item.get("date") or "").strip()
        if factor is None or not date:
            continue
        rows.append(GlobalStockSplit(date=date, split_factor=factor))
    return rows


def map_eod_quotes_with_change(
    items: Iterable[dict],
    *,
    category: str,
) -> list[MarketQuote]:
    grouped: dict[str, list[tuple[datetime | None, dict]]] = {}
    for item in items:
        symbol = str(item.get("symbol") or "").upper().strip()
        if not symbol:
            continue
        grouped.setdefault(symbol, []).append((_parse_date(item.get("date")), item))

    quotes: list[MarketQuote] = []
    for symbol, rows in grouped.items():
        rows.sort(key=lambda row: row[0] or datetime.min.replace(tzinfo=UTC), reverse=True)
        latest = rows[0][1]
        previous_close = None
        if len(rows) > 1:
            previous_close = _safe_float(
                rows[1][1].get("close") or rows[1][1].get("adj_close") or rows[1][1].get("last")
            )
        quote = map_eod_quote(latest, category=category, previous_close=previous_close)
        if quote:
            quotes.append(quote)
    return quotes


def map_eod_candles(items: Iterable[dict]) -> list[GlobalStockCandle]:
    candles: list[GlobalStockCandle] = []
    for item in items:
        close = _safe_float(item.get("close") or item.get("adj_close"))
        if close is None:
            continue
        parsed = _parse_date(item.get("date"))
        candles.append(
            GlobalStockCandle(
                date=(parsed.date().isoformat() if parsed else str(item.get("date") or "")),
                open=_safe_float(item.get("open") or item.get("adj_open")),
                high=_safe_float(item.get("high") or item.get("adj_high")),
                low=_safe_float(item.get("low") or item.get("adj_low")),
                close=close,
                adj_close=_safe_float(item.get("adj_close")),
                volume=_safe_float(item.get("volume")),
            )
        )
    candles.sort(key=lambda candle: candle.date)
    return candles


def map_exchange(item: dict) -> ExchangeInfo | None:
    mic = str(item.get("mic") or item.get("code") or "").upper().strip()
    name = str(item.get("name") or "").strip()
    if not mic or not name:
        return None

    country_name = str(item.get("country") or "").strip() or None
    country_code = str(item.get("country_code") or "").upper().strip() or None
    if country_code and len(country_code) > 2:
        country_code = country_code[:2]

    return ExchangeInfo(
        mic=mic,
        name=name,
        country=country_name,
        country_code=country_code,
        city=str(item.get("city") or "").strip() or None,
        website=str(item.get("website") or "").strip() or None,
        timezone=str(item.get("timezone") or "").strip() or None,
    )


def history_date_from(*, max_history_days: int) -> str:
    start = datetime.now(UTC).date() - timedelta(days=max(1, max_history_days))
    return start.isoformat()


# Marketstack MIC -> sufixo de bolsa usado pela Financial Modeling Prep nos logos.
# Ex.: SAP.XETRA (Marketstack) -> SAP.DE (FMP).
FMP_EXCHANGE_SUFFIX: dict[str, str] = {
    "XETRA": "DE",
    "XFRA": "DE",
    "ETR": "DE",
    "XLON": "L",
    "XPAR": "PA",
    "XAMS": "AS",
    "XBRU": "BR",
    "XLIS": "LS",
    "XMIL": "MI",
    "XMAD": "MC",
    "XSWX": "SW",
    "XVTX": "SW",
    "XWBO": "VI",
    "XSTO": "ST",
    "XCSE": "CO",
    "XHEL": "HE",
    "XOSL": "OL",
    "XTSE": "TO",
    "XTSX": "V",
    "XASX": "AX",
    "XTKS": "T",
    "XHKG": "HK",
    "XSHG": "SS",
    "XSHE": "SZ",
    "XNSE": "NS",
    "XBOM": "BO",
    "XKRX": "KS",
    "XTAI": "TW",
    "XSES": "SI",
    "XJSE": "JO",
    "XMEX": "MX",
}


def fmp_api_symbol(symbol: str) -> str:
    """Converte o ticker (formato Marketstack) para o formato da Financial
    Modeling Prep.

    Regras:
    - Classe de ação US (BRK.B / BRK-B) → mantém o ponto: ``BRK.B``.
    - Sufixo de bolsa (``SAP.XETRA``) → traduz o MIC para o sufixo FMP (``SAP.DE``).
    - MIC desconhecido → usa o ticker base (geralmente resolve a listagem primária).
    """
    upper = symbol.upper().strip()
    if "." in upper:
        base, suffix = upper.rsplit(".", 1)
        if len(suffix) == 1 and suffix.isalpha():
            return f"{base}.{suffix}"
        fmp_suffix = FMP_EXCHANGE_SUFFIX.get(suffix)
        return f"{base}.{fmp_suffix}" if fmp_suffix else base
    if "-" in upper:
        base, suffix = upper.rsplit("-", 1)
        if len(suffix) == 1 and suffix.isalpha():
            return f"{base}.{suffix}"
        return upper
    return upper


def us_logo_source_url(symbol: str) -> str:
    """Logo PNG da Financial Modeling Prep — funciona para ações dos EUA e para
    listagens internacionais usando o sufixo de bolsa da FMP."""
    return f"https://financialmodelingprep.com/image-stock/{fmp_api_symbol(symbol)}.png"


def with_us_logo(quote: MarketQuote) -> MarketQuote:
    return quote.model_copy(update={"logo_url": us_logo_source_url(quote.symbol)})
