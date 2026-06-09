from __future__ import annotations

from app.domain.crypto.models import CryptoCandle, CryptoCandlesResponse, CryptoListResponse, CryptoQuote
from app.domain.crypto.presets import CRYPTO_NAMES


def map_market_row(row: dict) -> CryptoQuote | None:
    if not isinstance(row, dict):
        return None
    symbol = str(row.get("symbol") or "").upper().strip()
    price = _float(row.get("current_price"))
    if not symbol or price is None or price <= 0:
        return None
    return CryptoQuote(
        symbol=symbol,
        name=str(row.get("name") or CRYPTO_NAMES.get(symbol, symbol)),
        price=price,
        change_percent=_float(row.get("price_change_percentage_24h")) or 0.0,
        change=_float(row.get("price_change_24h")),
        day_high=_float(row.get("high_24h")),
        day_low=_float(row.get("low_24h")),
        volume=_float(row.get("total_volume")),
        market_cap=_float(row.get("market_cap")),
        image_url=str(row.get("image") or "") or None,
        provider="coingecko",
    )


def map_markets_response(rows: object) -> CryptoListResponse:
    if not isinstance(rows, list):
        return CryptoListResponse(items=[], count=0, provider="coingecko")
    items: list[CryptoQuote] = []
    for row in rows:
        quote = map_market_row(row) if isinstance(row, dict) else None
        if quote is not None:
            items.append(quote)
    return CryptoListResponse(items=items, count=len(items), provider="coingecko")


def map_market_chart(
    symbol: str,
    payload: object,
    *,
    interval: str = "1d",
) -> CryptoCandlesResponse:
    if not isinstance(payload, dict):
        return CryptoCandlesResponse(
            symbol=symbol,
            interval=interval,
            candles=[],
            count=0,
            provider="coingecko",
        )

    prices = payload.get("prices") if isinstance(payload.get("prices"), list) else []
    candles: list[CryptoCandle] = []
    prev_close: float | None = None
    for point in prices:
        if not isinstance(point, list) or len(point) < 2:
            continue
        ts_ms, close = point[0], _float(point[1])
        if close is None or close <= 0:
            continue
        open_price = prev_close if prev_close is not None else close
        candles.append(
            CryptoCandle(
                date=_ms_to_date(ts_ms),
                open=open_price,
                high=max(open_price, close),
                low=min(open_price, close),
                close=close,
                volume=0.0,
            )
        )
        prev_close = close

    return CryptoCandlesResponse(
        symbol=symbol,
        interval=interval,
        candles=candles,
        count=len(candles),
        provider="coingecko",
    )


def _ms_to_date(value: object) -> str:
    try:
        ts = int(value) / 1000
    except (TypeError, ValueError):
        return ""
    from datetime import UTC, datetime

    return datetime.fromtimestamp(ts, tz=UTC).date().isoformat()


def _float(value: object) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None
