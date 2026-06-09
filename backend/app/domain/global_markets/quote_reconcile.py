from __future__ import annotations

from datetime import datetime

from app.clients.brapi.models import MarketQuote
from app.clients.marketstack.stock_mapper import _change_percent, map_eod_candles, normalize_marketstack_symbol
from app.domain.global_markets.models import GlobalStockCandle
from app.domain.global_markets.us_market_session import us_market_session


def _usable_close(candle: GlobalStockCandle) -> float | None:
    if candle.close is not None and candle.close > 0:
        return candle.close
    if candle.adj_close is not None and candle.adj_close > 0:
        return candle.adj_close
    return None


def _valid_candles(candles: list[GlobalStockCandle]) -> list[GlobalStockCandle]:
    valid: list[GlobalStockCandle] = []
    for candle in sorted(candles, key=lambda c: c.date):
        if _usable_close(candle) is None:
            continue
        valid.append(candle)
    return valid


def should_reconcile_quotes_to_eod(*, now: datetime | None = None) -> bool:
    """Alinha ao último candle EOD só fora do pregão ativo (incl. pré/after)."""
    session = us_market_session(now=now)
    return not (session["is_open"] or session["status"] in {"premarket", "afterhours"})


def _group_eod_rows_by_symbol(eod_rows: list[dict]) -> dict[str, list[dict]]:
    grouped: dict[str, list[dict]] = {}
    for row in eod_rows:
        symbol = str(row.get("symbol") or "").upper().strip()
        if not symbol:
            continue
        for key in (symbol, normalize_marketstack_symbol(symbol)):
            bucket = grouped.setdefault(key, [])
            if row not in bucket:
                bucket.append(row)
    return grouped


def reconcile_quotes_from_eod_rows(
    quotes: list[MarketQuote],
    eod_rows: list[dict],
) -> list[MarketQuote]:
    """Reconcilia lote usando linhas EOD já buscadas (sem chamadas extras)."""
    if not quotes or not eod_rows:
        return quotes

    by_symbol = _group_eod_rows_by_symbol(eod_rows)
    reconciled: list[MarketQuote] = []
    for quote in quotes:
        rows = (
            by_symbol.get(quote.symbol.upper())
            or by_symbol.get(normalize_marketstack_symbol(quote.symbol))
        )
        if not rows:
            reconciled.append(quote)
            continue
        candles = map_eod_candles(rows)
        reconciled.append(reconcile_quote_with_candles(quote, candles))
    return reconciled


def quote_looks_stale_during_session(quote: MarketQuote, *, now: datetime | None = None) -> bool:
    """Detecta fechamento anterior exibido como preço ao vivo no pregão."""
    session = us_market_session(now=now)
    if not (session["is_open"] or session["status"] in {"premarket", "afterhours"}):
        return False

    price = quote.price
    if price <= 0:
        return False

    low = quote.low
    if low is not None and low > 0 and low < price * 0.985:
        return True

    previous = quote.previous_close
    if previous is not None and previous > 0:
        if abs(price - previous) < 0.02 and quote.change_percent < -0.25:
            return True
        if price > previous and quote.change_percent < -0.5:
            return True

    return False


def apply_fmp_live_quote(quote: MarketQuote, fmp_row: dict) -> MarketQuote:
    """Sobrepõe preço/variação com cotação ao vivo da FMP."""
    price = _safe_float(fmp_row.get("price"))
    if price is None or price <= 0:
        return quote

    previous = _safe_float(
        fmp_row.get("previousClose")
        or fmp_row.get("previous_close")
        or fmp_row.get("prevClose")
    )
    change_pct = _safe_float(
        fmp_row.get("changesPercentage")
        or fmp_row.get("changePercentage")
        or fmp_row.get("changes_percent")
    )

    updates: dict = {
        "price": price,
        "provider": "marketstack+fmp",
    }
    if previous is not None and previous > 0:
        updates["previous_close"] = previous
        updates["change_percent"] = (
            round(change_pct, 4)
            if change_pct is not None
            else round(_change_percent(price, previous), 4)
        )
    elif change_pct is not None:
        updates["change_percent"] = round(change_pct, 4)

    for fmp_key, quote_key in (
        ("dayLow", "low"),
        ("dayHigh", "high"),
        ("open", "open"),
        ("volume", "volume"),
    ):
        value = _safe_float(fmp_row.get(fmp_key))
        if value is not None:
            updates[quote_key] = value

    return quote.model_copy(update=updates)


def _safe_float(value: object) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def reconcile_quote_with_candles(quote: MarketQuote, candles: list[GlobalStockCandle]) -> MarketQuote:
    """Alinha cotação exibida ao último candle EOD (preço e variação do dia)."""
    sorted_candles = _valid_candles(candles)
    if not sorted_candles:
        return quote

    last = sorted_candles[-1]
    price = _usable_close(last)
    if price is None or price <= 0:
        return quote

    previous_close = quote.previous_close
    if len(sorted_candles) >= 2:
        previous_close = _usable_close(sorted_candles[-2])

    change = round(_change_percent(price, previous_close), 2)
    updates: dict = {
        "price": price,
        "previous_close": previous_close,
        "change_percent": change,
        "session_date": last.date[:10] if last.date else quote.session_date,
    }
    if last.open is not None:
        updates["open"] = last.open
    if last.high is not None:
        updates["high"] = last.high
    if last.low is not None:
        updates["low"] = last.low
    if last.volume is not None:
        updates["volume"] = last.volume
    if last.adj_close is not None:
        updates["adj_close"] = last.adj_close

    return quote.model_copy(update=updates)
