from __future__ import annotations

from app.clients.brapi.models import StockMarketStats
from app.clients.brapi.models import FiiCandleBar
from app.domain.global_markets.analytics import _parse_day
from app.domain.global_markets.models import GlobalStockCandle

_FULL_YEAR_SESSIONS = 200


def _range_label(session_count: int) -> str:
    if session_count >= _FULL_YEAR_SESSIONS:
        return "52 semanas"
    return f"Últimos {session_count} pregões"


def enrich_market_stats_from_candles(
    stats: StockMarketStats,
    candles: list[GlobalStockCandle],
    *,
    week_sessions: int = 252,
    avg_volume_window: int = 20,
) -> StockMarketStats:
    """Preenche faixa de preços e volume médio a partir do histórico EOD (dados reais)."""
    if not candles:
        return stats

    sorted_candles = sorted(
        (c for c in candles if _parse_day(c.date) is not None),
        key=lambda c: c.date,
    )
    if not sorted_candles:
        return stats

    window = sorted_candles[-week_sessions:]
    session_count = len(window)
    highs: list[float] = []
    lows: list[float] = []
    for candle in window:
        high = candle.high if candle.high is not None else candle.close
        low = candle.low if candle.low is not None else candle.close
        if high is not None:
            highs.append(high)
        if low is not None:
            lows.append(low)

    updates: dict[str, float | str | int] = {}
    if highs and lows and session_count >= 5:
        week_high = round(max(highs), 4)
        week_low = round(min(lows), 4)
        updates["fifty_two_week_high"] = week_high
        updates["fifty_two_week_low"] = week_low
        updates["fifty_two_week_range"] = f"{week_low:.2f} - {week_high:.2f}"
        updates["price_range_sessions"] = session_count
        updates["price_range_label"] = _range_label(session_count)

    vol_window = sorted_candles[-avg_volume_window:]
    volumes = [c.volume for c in vol_window if c.volume is not None and c.volume > 0]
    if volumes:
        updates["avg_daily_volume"] = round(sum(volumes) / len(volumes), 2)

    if not updates:
        return stats
    return stats.model_copy(update=updates)


def enrich_market_stats_from_fii_candles(
    stats: StockMarketStats,
    candles: list[FiiCandleBar],
    *,
    week_sessions: int = 252,
    avg_volume_window: int = 20,
) -> StockMarketStats:
    """Preenche faixa de preços e volume médio a partir de candles B3 (Bolsai/Brapi)."""
    if not candles:
        return stats

    sorted_candles = sorted(
        (c for c in candles if _parse_day(c.trade_date) is not None),
        key=lambda c: c.trade_date,
    )
    if not sorted_candles:
        return stats

    window = sorted_candles[-week_sessions:]
    session_count = len(window)
    highs: list[float] = []
    lows: list[float] = []
    for candle in window:
        high = candle.high if candle.high is not None else candle.close
        low = candle.low if candle.low is not None else candle.close
        highs.append(high)
        lows.append(low)

    updates: dict[str, float | str | int] = {}
    if highs and lows and session_count >= 5:
        week_high = round(max(highs), 4)
        week_low = round(min(lows), 4)
        updates["fifty_two_week_high"] = week_high
        updates["fifty_two_week_low"] = week_low
        updates["fifty_two_week_range"] = f"{week_low:.2f} - {week_high:.2f}"
        updates["price_range_sessions"] = session_count
        updates["price_range_label"] = _range_label(session_count)

    vol_window = sorted_candles[-avg_volume_window:]
    volumes = [c.volume for c in vol_window if c.volume is not None and c.volume > 0]
    if volumes:
        updates["avg_daily_volume"] = round(sum(volumes) / len(volumes), 2)

    if not updates:
        return stats
    return stats.model_copy(update=updates)
