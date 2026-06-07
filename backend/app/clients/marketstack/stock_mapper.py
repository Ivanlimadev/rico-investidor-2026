from __future__ import annotations

from collections.abc import Iterable
from datetime import UTC, datetime, timedelta
from zoneinfo import ZoneInfo

from app.clients.brapi.models import MarketQuote
from app.domain.global_markets.models import (
    ExchangeInfo,
    GlobalStockCandle,
    GlobalStockDividend,
    GlobalStockSplit,
    GlobalStockTickerInfo,
)
from app.domain.global_markets.us_dividend_dates import investidor10_com_date, normalize_us_market_day
from app.domain.global_markets.presets import US_TICKER_NAMES


def _safe_float(value: object) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _eod_session_close(item: dict) -> float | None:
    """Fechamento nominal do pregão (não usa adj_close como preço)."""
    return _safe_float(item.get("close") or item.get("last"))


def _effective_eod_close(item: dict) -> float | None:
    """Fechamento utilizável: ignora zeros da API e cai para adj_close."""
    close = _eod_session_close(item)
    if close is not None and close > 0:
        return close
    adj = _safe_float(item.get("adj_close"))
    if adj is not None and adj > 0:
        return adj
    return None


def _eod_session_open(item: dict) -> float | None:
    return _safe_float(item.get("open"))


def _eod_session_high(item: dict) -> float | None:
    return _safe_float(item.get("high"))


def _eod_session_low(item: dict) -> float | None:
    return _safe_float(item.get("low"))


def _eod_session_volume(item: dict) -> float | None:
    return _safe_float(item.get("volume"))


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
    close = _effective_eod_close(item)
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
        open=_eod_session_open(item),
        high=_eod_session_high(item),
        low=_eod_session_low(item),
        volume=_eod_session_volume(item),
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


def _normalize_day(value: object) -> str | None:
    return normalize_us_market_day(value)


def map_dividends(items: Iterable[dict]) -> list[GlobalStockDividend]:
    rows: list[GlobalStockDividend] = []
    for item in items:
        amount = _safe_float(item.get("dividend") or item.get("amount"))
        ex_date = normalize_us_market_day(item.get("date"))
        if amount is None or not ex_date:
            continue
        frequency = str(item.get("distr_freq") or item.get("frequency") or "").strip().lower() or None
        rows.append(
            GlobalStockDividend(
                date=ex_date,
                amount=amount,
                ex_date=ex_date,
                com_date=investidor10_com_date(ex_date),
                record_date=normalize_us_market_day(item.get("record_date") or item.get("recordDate")),
                payment_date=normalize_us_market_day(item.get("payment_date") or item.get("paymentDate")),
                declaration_date=normalize_us_market_day(
                    item.get("declaration_date") or item.get("declarationDate")
                ),
                frequency=frequency,
            )
        )
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


def filter_today_intraday_rows(
    items: Iterable[dict],
    *,
    today: str | None = None,
) -> list[dict]:
    """Descarta barras intraday de sessões anteriores (ex.: sexta no domingo)."""
    if today is None:
        today = datetime.now(ZoneInfo("America/New_York")).date().isoformat()
    return [item for item in items if _session_date(item) == today]


def overlay_intraday_prices(
    quotes: list[MarketQuote],
    intraday_items: Iterable[dict],
) -> list[MarketQuote]:
    """Atualiza preço ao vivo mantendo previous_close e variação do pregão EOD."""
    live_by_key: dict[str, dict] = {}
    for item in intraday_items:
        symbol = str(item.get("symbol") or "").upper().strip()
        if not symbol:
            continue
        price = _effective_eod_close(item)
        if price is None:
            continue
        live_by_key[symbol] = item
        live_by_key[normalize_marketstack_symbol(symbol)] = item

    updated: list[MarketQuote] = []
    for quote in quotes:
        item = live_by_key.get(quote.symbol.upper()) or live_by_key.get(
            normalize_marketstack_symbol(quote.symbol)
        )
        if item is None:
            updated.append(quote)
            continue
        price = _effective_eod_close(item)
        if price is None:
            updated.append(quote)
            continue
        prev = quote.previous_close
        updated.append(
            quote.model_copy(
                update={
                    "price": price,
                    "change_percent": _change_percent(price, prev),
                    "open": _eod_session_open(item) or quote.open,
                    "high": _eod_session_high(item) or quote.high,
                    "low": _eod_session_low(item) or quote.low,
                    "volume": _eod_session_volume(item) or quote.volume,
                    "session_date": _session_date(item) or quote.session_date,
                }
            )
        )
    return updated


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
        latest_item = None
        previous_close = None
        for index, (_, item) in enumerate(rows):
            if _effective_eod_close(item) is None:
                continue
            if latest_item is None:
                latest_item = item
                continue
            if previous_close is None:
                previous_close = _effective_eod_close(item)
                break
        if latest_item is None:
            continue
        quote = map_eod_quote(latest_item, category=category, previous_close=previous_close)
        if quote:
            quotes.append(quote)
    return quotes


def sparklines_from_eod_items(
    items: Iterable[dict],
    *,
    max_points: int = 24,
) -> dict[str, list[float]]:
    """Agrupa fechamentos EOD por símbolo (ordem cronológica) para mini-gráficos."""
    grouped: dict[str, list[tuple[datetime | None, float]]] = {}
    for item in items:
        symbol = str(item.get("symbol") or "").upper().strip()
        if not symbol:
            continue
        close = _effective_eod_close(item)
        if close is None:
            continue
        grouped.setdefault(symbol, []).append((_parse_date(item.get("date")), close))

    result: dict[str, list[float]] = {}
    cap = max(2, min(max_points, 60))
    for symbol, rows in grouped.items():
        rows.sort(key=lambda row: row[0] or datetime.min.replace(tzinfo=UTC))
        closes = [price for _, price in rows]
        if len(closes) > cap:
            closes = closes[-cap:]
        if len(closes) >= 2:
            result[symbol] = closes
    return result


def map_eod_candles(items: Iterable[dict]) -> list[GlobalStockCandle]:
    candles: list[GlobalStockCandle] = []
    for item in items:
        close = _effective_eod_close(item)
        if close is None:
            continue
        parsed = _parse_date(item.get("date"))
        candles.append(
            GlobalStockCandle(
                date=(parsed.date().isoformat() if parsed else str(item.get("date") or "")),
                open=_eod_session_open(item),
                high=_eod_session_high(item),
                low=_eod_session_low(item),
                close=close,
                adj_close=_safe_float(item.get("adj_close")),
                volume=_eod_session_volume(item),
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
