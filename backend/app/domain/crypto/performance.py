"""Cálculo de variação percentual a partir de candles diários Binance."""

from __future__ import annotations

from app.domain.crypto.models import CryptoCandle, CryptoPerformanceStats


def calc_performance_stats(
    candles: list[CryptoCandle],
    *,
    current_price: float,
    change_24h: float | None = None,
) -> CryptoPerformanceStats:
    if not candles:
        return CryptoPerformanceStats(change_24h=change_24h)

    def change_over_days(days: int) -> float | None:
        if days <= 0:
            return None
        index = len(candles) - 1 - days
        if index < 0:
            return None
        reference = candles[index].close
        if reference <= 0:
            return None
        return ((current_price - reference) / reference) * 100.0

    return CryptoPerformanceStats(
        change_24h=change_24h,
        change_7d=change_over_days(7),
        change_30d=change_over_days(30),
        change_1y=change_over_days(365),
    )
