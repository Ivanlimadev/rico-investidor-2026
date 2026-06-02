from app.domain.crypto.models import CryptoCandle, CryptoPerformanceStats
from app.domain.crypto.performance import calc_performance_stats


def test_calc_performance_stats_from_daily_candles():
    candles = [
        CryptoCandle(date=f"d{i}", open=100, high=100, low=100, close=100 + i, volume=1)
        for i in range(400)
    ]
    current = 500.0

    stats = calc_performance_stats(candles, current_price=current, change_24h=1.5)

    assert isinstance(stats, CryptoPerformanceStats)
    assert stats.change_24h == 1.5
    assert stats.change_7d is not None
    assert stats.change_30d is not None
    assert stats.change_1y is not None
    # 7 dias atrás close = 100 + (400 - 1 - 7) = 392? 
    # len=400, index -1 is 499, index -8 is 492 close = 100+392=492? 
    # candles[i].close = 100+i, last index 399 close=499
    # 7 days back: index 399-7=392, close=492
    expected_7d = ((500 - 492) / 492) * 100
    assert stats.change_7d == round(expected_7d, 6) or abs(stats.change_7d - expected_7d) < 0.001


def test_calc_performance_stats_empty_candles():
    stats = calc_performance_stats([], current_price=100, change_24h=-2.0)
    assert stats.change_24h == -2.0
    assert stats.change_7d is None
