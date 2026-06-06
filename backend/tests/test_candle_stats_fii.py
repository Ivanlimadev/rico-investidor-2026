from app.clients.brapi.models import StockMarketStats
from app.domain.fii.models import FiiCandleBar
from app.domain.global_markets.candle_stats import enrich_market_stats_from_fii_candles


def test_enrich_market_stats_from_fii_candles_fills_range_and_avg_volume():
    candles = [
        FiiCandleBar(trade_date="2024-01-02", open=10, high=11, low=9, close=10, volume=1_000_000),
        FiiCandleBar(trade_date="2024-06-01", open=20, high=25, low=8, close=20, volume=2_000_000),
        FiiCandleBar(trade_date="2025-01-02", open=18, high=22, low=15, close=19, volume=3_000_000),
        FiiCandleBar(trade_date="2025-02-01", open=19, high=23, low=17, close=21, volume=4_000_000),
        FiiCandleBar(trade_date="2025-03-01", open=21, high=24, low=18, close=22, volume=5_000_000),
    ]

    enriched = enrich_market_stats_from_fii_candles(StockMarketStats(), candles, avg_volume_window=2)

    assert enriched.fifty_two_week_low == 8.0
    assert enriched.fifty_two_week_high == 25.0
    assert enriched.avg_daily_volume == 4_500_000.0
    assert enriched.price_range_label == "Últimos 5 pregões"
