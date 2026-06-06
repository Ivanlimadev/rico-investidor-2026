from datetime import UTC, datetime, timedelta

from app.domain.fii.models import FiiCandleBar, FiiDistributionPayment
from app.domain.quotes.stock_returns import compute_stock_returns


def _series(count: int, *, start_price: float, end_price: float) -> list[FiiCandleBar]:
    start = datetime(2024, 1, 2, tzinfo=UTC)
    bars: list[FiiCandleBar] = []
    for index in range(count):
        day = (start + timedelta(days=index)).strftime("%Y-%m-%d")
        price = start_price + ((end_price - start_price) * index / max(count - 1, 1))
        bars.append(
            FiiCandleBar(
                trade_date=day,
                open=price,
                high=price,
                low=price,
                close=price,
            )
        )
    return bars


def test_compute_stock_returns_uses_sessions_and_dividends():
    candles = _series(300, start_price=100.0, end_price=100.0)
    payments = [
        FiiDistributionPayment(
            payment_date="2025-06-01",
            value_per_share=5.0,
        )
    ]

    rows = compute_stock_returns(candles, current_price=110.0, payments=payments)
    one_year = next(row for row in rows if row.label == "1A")

    assert one_year.return_pct == 15.0
    assert one_year.months_back == 12
