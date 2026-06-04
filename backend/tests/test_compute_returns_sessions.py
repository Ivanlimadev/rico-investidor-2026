from app.domain.global_markets.analytics import compute_returns
from app.domain.global_markets.models import GlobalStockCandle


def test_compute_returns_uses_trading_sessions():
    candles = [
        GlobalStockCandle(date=f"2024-{i:03d}-15", close=float(i + 1))
        for i in range(70)
    ]

    rows = compute_returns(candles, current_price=70.0)

    by_label = {row.label: row.return_pct for row in rows}
    assert "1M" in by_label
    assert "3M" in by_label
    assert by_label["3M"] == 900.0
