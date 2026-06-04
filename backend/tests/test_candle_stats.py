from app.clients.brapi.models import StockMarketStats
from app.domain.global_markets.candle_stats import enrich_market_stats_from_candles
from app.domain.global_markets.models import GlobalStockCandle


def test_enrich_market_stats_from_candles_fills_range_and_avg_volume():
    candles = [
        GlobalStockCandle(date="2024-01-02", close=10.0, high=11.0, low=9.0, volume=1_000_000),
        GlobalStockCandle(date="2024-06-01", close=20.0, high=25.0, low=8.0, volume=2_000_000),
        GlobalStockCandle(date="2025-01-02", close=18.0, high=22.0, low=15.0, volume=3_000_000),
        GlobalStockCandle(date="2025-02-01", close=19.0, high=20.0, low=17.0, volume=4_000_000),
        GlobalStockCandle(date="2025-03-01", close=21.0, high=23.0, low=18.0, volume=5_000_000),
    ]
    stats = StockMarketStats(volume=5_000_000, provider="marketstack")

    enriched = enrich_market_stats_from_candles(stats, candles, week_sessions=252, avg_volume_window=2)

    assert enriched.fifty_two_week_high == 25.0
    assert enriched.fifty_two_week_low == 8.0
    assert enriched.price_range_sessions == 5
    assert enriched.price_range_label == "Últimos 5 pregões"
    assert enriched.avg_daily_volume == 4_500_000
