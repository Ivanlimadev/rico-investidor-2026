from app.clients.brapi.models import StockDividendsResponse, StockDividendsSummary, StockFundamentals
from app.clients.bolsai.fundamentals_mapper import merge_bolsai_fundamentals
from app.domain.fii.models import FiiCandleBar
from app.domain.quotes.compare_enrichment import (
    dividends_snapshot_from_stock,
    return_periods_from_ticker_candles,
    return_periods_from_performance,
)


def test_dividends_snapshot_from_stock_uses_display_dy():
    dividends = StockDividendsResponse(
        ticker="PETR4",
        count=1,
        dividend_yield_ttm=5.65,
        summary=StockDividendsSummary(dividend_yield_display=6.97, ttm_per_share_display=2.88),
        provider="bolsai",
    )
    snap = dividends_snapshot_from_stock(dividends)
    assert snap.dividend_yield_display == 6.97
    assert snap.ttm_per_share == 2.88


def test_merge_bolsai_fundamentals():
    base = StockFundamentals(price_earnings=10.0)
    merged = merge_bolsai_fundamentals(
        base,
        {"price_earnings": 4.94, "price_to_book": 1.19, "return_on_equity": 24.17},
    )
    assert merged.price_earnings == 4.94
    assert merged.price_to_book == 1.19
    assert merged.return_on_equity == 24.17


def test_return_periods_from_performance():
    rows = return_periods_from_performance(one_month=2.5, ytd=10.0, one_year=15.0)
    labels = [row.label for row in rows]
    assert labels == ["1M", "YTD", "1A"]


def test_return_periods_from_ticker_candles_single_series():
    candles = [
        FiiCandleBar(trade_date="2025-12-15", open=90, high=90, low=90, close=90),
        FiiCandleBar(trade_date="2026-01-02", open=100, high=100, low=100, close=100),
        FiiCandleBar(trade_date="2026-05-25", open=110, high=110, low=110, close=110),
    ]
    rows = return_periods_from_ticker_candles(candles, as_of=__import__("datetime").date(2026, 5, 25))
    labels = [row.label for row in rows]
    assert labels == ["YTD", "1A"]
    ytd = next(row for row in rows if row.label == "YTD")
    assert ytd.return_pct == 10.0
