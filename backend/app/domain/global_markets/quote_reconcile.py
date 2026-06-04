from __future__ import annotations

from app.clients.brapi.models import MarketQuote
from app.clients.marketstack.stock_mapper import _change_percent
from app.domain.global_markets.models import GlobalStockCandle


def reconcile_quote_with_candles(quote: MarketQuote, candles: list[GlobalStockCandle]) -> MarketQuote:
    """Alinha cotação exibida ao último candle EOD (preço e variação do dia)."""
    if len(candles) < 1:
        return quote

    sorted_candles = sorted(candles, key=lambda c: c.date)
    last = sorted_candles[-1]
    price = last.close
    if price is None or price <= 0:
        return quote

    previous_close = quote.previous_close
    if len(sorted_candles) >= 2:
        previous_close = sorted_candles[-2].close

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
