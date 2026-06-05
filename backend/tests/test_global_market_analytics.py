from datetime import UTC, datetime, timedelta

from app.domain.global_markets.analytics import (
    build_company_profile,
    compute_returns,
    summarize_dividends,
)
from app.domain.global_markets.models import (
    GlobalStockCandle,
    GlobalStockDividend,
    GlobalStockTickerInfo,
)


def test_summarize_dividends_ttm_and_yield():
    now = datetime(2026, 5, 25, tzinfo=UTC)
    dividends = [
        GlobalStockDividend(date="2026-03-01", amount=0.25),
        GlobalStockDividend(date="2025-12-01", amount=0.24),
        GlobalStockDividend(date="2024-06-01", amount=0.20),
    ]

    summary = summarize_dividends(dividends, price=100.0, as_of=now)

    assert summary.ttm_per_share == 0.49
    assert summary.dividend_yield_ttm == 0.49
    assert summary.payments_12m == 2
    assert summary.total_payments == 3
    assert summary.annual_totals[0]["year"] == 2026
    assert summary.annual_totals[0]["payments"] == 1


def test_summarize_dividends_annual_uses_payment_year_when_available():
    now = datetime(2026, 5, 25, tzinfo=UTC)
    dividends = [
        GlobalStockDividend(
            date="2025-12-01",
            amount=0.24,
            ex_date="2025-12-01",
            payment_date="2026-01-05",
        ),
    ]

    summary = summarize_dividends(dividends, price=100.0, as_of=now)

    assert summary.annual_totals[0]["year"] == 2026
    assert summary.annual_totals[0]["total"] == 0.24


def test_compute_returns_from_candles():
    """Rentabilidade 1A usa ~252 pregões, não datas de calendário."""
    start = datetime(2024, 1, 2, tzinfo=UTC)
    candles = [
        GlobalStockCandle(
            date=(start + timedelta(days=i)).strftime("%Y-%m-%d"),
            close=90.0,
        )
        for i in range(253)
    ]
    candles[-1] = GlobalStockCandle(date="2026-05-20", close=100)

    rows = compute_returns(candles, current_price=100, as_of=datetime(2026, 5, 25, tzinfo=UTC))

    assert rows
    one_year = next(r for r in rows if r.label == "1A")
    assert one_year.return_pct is not None
    assert one_year.return_pct == 11.11


def test_compute_returns_includes_ytd():
    candles = [
        GlobalStockCandle(date="2025-12-15", close=90.0),
        GlobalStockCandle(date="2026-01-03", close=95.0),
        GlobalStockCandle(date="2026-05-20", close=100.0),
    ]
    rows = compute_returns(candles, current_price=100.0, as_of=datetime(2026, 5, 25, tzinfo=UTC))
    ytd = next((r for r in rows if r.label == "YTD"), None)
    assert ytd is not None
    assert ytd.return_pct == 5.26


def test_build_company_profile():
    ticker = GlobalStockTickerInfo(
        symbol="AAPL",
        name="Apple Inc.",
        country="United States",
        exchange_mic="XNAS",
        exchange_name="NASDAQ",
        isin="US0378331005",
    )

    profile = build_company_profile(ticker)

    assert profile.symbol == "AAPL"
    assert profile.exchange_mic == "XNAS"
    assert profile.isin == "US0378331005"
