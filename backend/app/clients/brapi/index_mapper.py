from __future__ import annotations

from app.domain.indices.models import IndexHistoryPoint, IndexQuote
from app.domain.indices.presets import INDEX_BY_SYMBOL, IndexPreset


def normalize_index_symbol(raw: str) -> str:
    cleaned = raw.strip().upper()
    if cleaned.startswith("^"):
        return cleaned
    aliases = {
        "IBOV": "^BVSP",
        "BVSP": "^BVSP",
        "SPX": "^GSPC",
        "SP500": "^GSPC",
        "NASDAQ": "^IXIC",
        "NDX": "^NDX",
        "DJI": "^DJI",
        "DOW": "^DJI",
    }
    return aliases.get(cleaned, cleaned)


def _to_float(value: object | None) -> float | None:
    if value is None or value == "":
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def map_index_quote(item: dict, *, preset: IndexPreset | None = None) -> IndexQuote:
    symbol = normalize_index_symbol(str(item.get("symbol") or preset.symbol if preset else ""))
    catalog = preset or INDEX_BY_SYMBOL.get(symbol)
    name = (
        (catalog.name if catalog else None)
        or item.get("longName")
        or item.get("shortName")
        or symbol
    )
    group = catalog.group if catalog else "brasil"
    return IndexQuote(
        symbol=symbol,
        name=str(name),
        group=group,
        price=float(item.get("regularMarketPrice") or 0),
        change_percent=float(item.get("regularMarketChangePercent") or 0),
        day_high=_to_float(item.get("regularMarketDayHigh")),
        day_low=_to_float(item.get("regularMarketDayLow")),
        previous_close=_to_float(item.get("regularMarketPreviousClose")),
        fifty_two_week_high=_to_float(item.get("fiftyTwoWeekHigh")),
        fifty_two_week_low=_to_float(item.get("fiftyTwoWeekLow")),
    )


def map_index_history(candles: list, *, symbol: str) -> list[IndexHistoryPoint]:
    history: list[IndexHistoryPoint] = []
    for candle in candles:
        trade_date = getattr(candle, "trade_date", None) or candle.get("trade_date") or candle.get("date")
        close = getattr(candle, "close", None)
        if close is None and isinstance(candle, dict):
            close = candle.get("close")
        if trade_date is None or close is None:
            continue
        history.append(IndexHistoryPoint(date=str(trade_date), value=float(close)))
    history.sort(key=lambda point: point.date)
    return history
