from __future__ import annotations

import json
from datetime import UTC, datetime

from app.domain.crypto.models import (
    CryptoAvailableResponse,
    CryptoCandle,
    CryptoCandlesResponse,
    CryptoHistoryPoint,
    CryptoHistoryResponse,
    CryptoListResponse,
    CryptoOrderBook,
    CryptoOrderBookLevel,
    CryptoQuote,
    CryptoRecentTrade,
    CryptoRecentTradesResponse,
)
from app.domain.crypto.presets import CRYPTO_NAMES, DISPLAY_CURRENCY, QUOTE_ASSET


def normalize_crypto_symbol(raw: str) -> str:
    cleaned = raw.strip().upper()
    if cleaned.endswith(QUOTE_ASSET) and len(cleaned) > len(QUOTE_ASSET):
        return cleaned[: -len(QUOTE_ASSET)]
    return cleaned


def to_usdt_pair(base: str) -> str:
    return f"{normalize_crypto_symbol(base)}{QUOTE_ASSET}"


def pair_to_base(pair: str) -> str:
    normalized = pair.strip().upper()
    if normalized.endswith(QUOTE_ASSET):
        return normalized[: -len(QUOTE_ASSET)]
    return normalized


def crypto_icon_url(symbol: str) -> str:
    slug = normalize_crypto_symbol(symbol).lower()
    return f"https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/svg/color/{slug}.svg"


def crypto_display_name(symbol: str) -> str:
    base = normalize_crypto_symbol(symbol)
    return CRYPTO_NAMES.get(base, base)


def _to_float(value: object | None) -> float | None:
    if value is None or value == "":
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _ms_to_iso(value: int | None) -> str | None:
    if value is None:
        return None
    return datetime.fromtimestamp(value / 1000, tz=UTC).isoformat()


def _ms_to_date(value: int) -> str:
    return datetime.fromtimestamp(value / 1000, tz=UTC).strftime("%Y-%m-%d")


def map_ticker_24hr(item: dict, *, currency: str = DISPLAY_CURRENCY) -> CryptoQuote:
    base = pair_to_base(str(item.get("symbol") or ""))
    price = _to_float(item.get("lastPrice"))
    return CryptoQuote(
        symbol=base,
        name=crypto_display_name(base),
        currency=currency,
        price=price if price is not None else 0.0,
        change_percent=_to_float(item.get("priceChangePercent")) or 0.0,
        change=_to_float(item.get("priceChange")),
        day_high=_to_float(item.get("highPrice")),
        day_low=_to_float(item.get("lowPrice")),
        volume=_to_float(item.get("quoteVolume")),
        market_cap=None,
        image_url=crypto_icon_url(base),
        updated_at=_ms_to_iso(item.get("closeTime")),
        provider="binance",
    )


def map_ticker_24hr_batch(data: list[dict] | dict, *, currency: str = DISPLAY_CURRENCY) -> CryptoListResponse:
    if isinstance(data, dict):
        items = [map_ticker_24hr(data, currency=currency)]
    else:
        items = [map_ticker_24hr(item, currency=currency) for item in data if isinstance(item, dict)]
    return CryptoListResponse(items=items, count=len(items), provider="binance")


def map_usdt_catalog(pairs: list[str]) -> CryptoAvailableResponse:
    coins = sorted({pair_to_base(pair) for pair in pairs if pair.strip()})
    return CryptoAvailableResponse(coins=coins, count=len(coins), provider="binance")


def map_klines(data: list[list], *, symbol: str, currency: str = DISPLAY_CURRENCY, limit: int) -> CryptoHistoryResponse:
    candles = map_klines_candles(data, symbol=symbol, currency=currency, interval="1d", limit=limit)
    history = [CryptoHistoryPoint(date=candle.date, value=candle.close) for candle in candles.candles]
    return CryptoHistoryResponse(
        symbol=candles.symbol,
        currency=currency,
        history=history,
        count=len(history),
        provider="binance",
    )


def map_klines_candles(
    data: list[list],
    *,
    symbol: str,
    currency: str = DISPLAY_CURRENCY,
    interval: str,
    limit: int,
) -> CryptoCandlesResponse:
    normalized = normalize_crypto_symbol(symbol)
    candles: list[CryptoCandle] = []
    for row in data:
        if not isinstance(row, list) or len(row) < 6:
            continue
        open_time = row[0]
        open_ = _to_float(row[1])
        high = _to_float(row[2])
        low = _to_float(row[3])
        close = _to_float(row[4])
        volume = _to_float(row[5])
        if None in (open_, high, low, close, volume) or open_time is None:
            continue
        candles.append(
            CryptoCandle(
                date=_ms_to_date(int(open_time)),
                open=open_,
                high=high,
                low=low,
                close=close,
                volume=volume,
            )
        )

    candles.sort(key=lambda item: item.date)
    if limit > 0 and len(candles) > limit:
        candles = candles[-limit:]

    return CryptoCandlesResponse(
        symbol=normalized,
        currency=currency,
        interval=interval,
        candles=candles,
        count=len(candles),
        provider="binance",
    )


def map_book_ticker(item: dict, *, symbol: str) -> CryptoQuote:
    base = normalize_crypto_symbol(symbol)
    bid = _to_float(item.get("bidPrice"))
    ask = _to_float(item.get("askPrice"))
    spread = None
    spread_percent = None
    if bid is not None and ask is not None:
        spread = ask - bid
        mid = (ask + bid) / 2
        if mid > 0:
            spread_percent = (spread / mid) * 100
    mid_price = ((bid or 0) + (ask or 0)) / 2 if bid is not None and ask is not None else 0.0
    return CryptoQuote(
        symbol=base,
        name=crypto_display_name(base),
        currency=DISPLAY_CURRENCY,
        price=mid_price,
        change_percent=0.0,
        bid_price=bid,
        ask_price=ask,
        spread=spread,
        spread_percent=spread_percent,
        image_url=crypto_icon_url(base),
        provider="binance",
    )


def merge_book_into_quote(quote: CryptoQuote, book: CryptoQuote) -> CryptoQuote:
    return quote.model_copy(
        update={
            "bid_price": book.bid_price,
            "ask_price": book.ask_price,
            "spread": book.spread,
            "spread_percent": book.spread_percent,
        }
    )


def map_depth(data: dict, *, symbol: str) -> CryptoOrderBook:
    bids = [
        CryptoOrderBookLevel(price=price, quantity=qty)
        for price, qty in (_parse_depth_level(level) for level in data.get("bids") or [])
        if price is not None and qty is not None
    ]
    asks = [
        CryptoOrderBookLevel(price=price, quantity=qty)
        for price, qty in (_parse_depth_level(level) for level in data.get("asks") or [])
        if price is not None and qty is not None
    ]
    return CryptoOrderBook(
        symbol=normalize_crypto_symbol(symbol),
        bids=bids,
        asks=asks,
        provider="binance",
    )


def _parse_depth_level(level: object) -> tuple[float | None, float | None]:
    if not isinstance(level, list) or len(level) < 2:
        return None, None
    return _to_float(level[0]), _to_float(level[1])


def map_recent_trades(data: list[dict], *, symbol: str) -> CryptoRecentTradesResponse:
    trades: list[CryptoRecentTrade] = []
    for item in data:
        if not isinstance(item, dict):
            continue
        price = _to_float(item.get("price"))
        qty = _to_float(item.get("qty"))
        trade_id = item.get("id")
        trade_time = item.get("time")
        if price is None or qty is None or trade_id is None or trade_time is None:
            continue
        trades.append(
            CryptoRecentTrade(
                id=int(trade_id),
                price=price,
                quantity=qty,
                time=_ms_to_iso(int(trade_time)) or "",
                is_buyer_maker=bool(item.get("isBuyerMaker")),
            )
        )
    return CryptoRecentTradesResponse(
        symbol=normalize_crypto_symbol(symbol),
        trades=trades,
        count=len(trades),
        provider="binance",
    )


def map_mini_ticker_event(data: dict) -> dict | None:
    if data.get("e") not in {None, "24hrMiniTicker"} and "c" not in data:
        return None
    price = _to_float(data.get("c"))
    if price is None:
        return None
    open_price = _to_float(data.get("o"))
    change_percent = None
    if open_price and open_price > 0:
        change_percent = ((price - open_price) / open_price) * 100
    return {
        "symbol": pair_to_base(str(data.get("s") or "")),
        "price": price,
        "change_percent": change_percent,
    }


def map_trade_event(data: dict) -> dict | None:
    if data.get("e") != "trade":
        return None
    price = _to_float(data.get("p"))
    if price is None:
        return None
    return {
        "symbol": pair_to_base(str(data.get("s") or "")),
        "price": price,
        "time": _ms_to_iso(int(data["T"])) if data.get("T") is not None else None,
    }


def encode_symbols_param(pairs: list[str]) -> str:
    return json.dumps(pairs, separators=(",", ":"))
