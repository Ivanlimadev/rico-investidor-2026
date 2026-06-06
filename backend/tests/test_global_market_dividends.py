from datetime import UTC, datetime

from app.clients.marketstack.stock_mapper import map_dividends
from app.domain.global_markets.analytics import summarize_dividends
from app.domain.global_markets.dividend_analytics import (
    enrich_dividend_dates,
    pick_next_dividend,
    project_next_dividend,
)
from app.domain.global_markets.models import GlobalStockDividend


def test_map_dividends_parses_marketstack_v2_fields():
    rows = map_dividends(
        [
            {
                "date": "2026-05-11",
                "dividend": 0.27,
                "payment_date": "2026-05-14 04:00:00",
                "record_date": "2026-05-11 04:00:00",
                "declaration_date": "2026-04-30 00:00:00",
                "distr_freq": "q",
            }
        ]
    )

    assert len(rows) == 1
    item = rows[0]
    assert item.amount == 0.27
    assert item.ex_date == "2026-05-11"
    assert item.record_date == "2026-05-11"
    assert item.payment_date == "2026-05-14"
    assert item.com_date == "2026-05-08"
    assert item.declaration_date == "2026-04-30"
    assert item.frequency == "q"


def test_summarize_dividends_includes_frequency_and_next():
    now = datetime(2026, 5, 25, tzinfo=UTC)
    dividends = [
        GlobalStockDividend(
            date="2026-05-11",
            amount=0.27,
            ex_date="2026-05-11",
            payment_date="2026-05-14",
            frequency="q",
        ),
        GlobalStockDividend(
            date="2026-02-09",
            amount=0.26,
            ex_date="2026-02-09",
            payment_date="2026-02-12",
            frequency="q",
        ),
        GlobalStockDividend(date="2024-06-01", amount=0.20, ex_date="2024-06-01"),
    ]

    summary = summarize_dividends(dividends, price=100.0, as_of=now)

    assert summary.frequency_label == "Trimestral"
    assert summary.avg_amount_12m == 0.265
    assert summary.next_dividend is not None
    assert summary.next_dividend.is_projected is True


def test_summarize_dividends_uses_payment_window_for_ttm():
    now = datetime(2026, 5, 25, tzinfo=UTC)
    dividends = [
        GlobalStockDividend(
            date="2024-06-01",
            amount=1.0,
            ex_date="2024-06-01",
            payment_date="2024-06-15",
        ),
        GlobalStockDividend(
            date="2026-05-11",
            amount=0.27,
            ex_date="2026-05-11",
            payment_date="2026-05-14",
        ),
        GlobalStockDividend(
            date="2026-02-09",
            amount=0.26,
            ex_date="2026-02-09",
            payment_date="2026-02-12",
        ),
    ]

    summary = summarize_dividends(dividends, price=100.0, as_of=now)

    assert summary.ttm_per_share == 0.53
    assert summary.payments_12m == 2
    assert summary.dividend_yield_ttm == 0.53


def test_pick_next_dividend_prefers_announced_upcoming():
    now = datetime(2026, 5, 25, tzinfo=UTC)
    announced = GlobalStockDividend(
        date="2026-06-10",
        amount=0.30,
        ex_date="2026-06-10",
        payment_date="2026-06-13",
        frequency="q",
    )
    historical = GlobalStockDividend(
        date="2026-02-09",
        amount=0.26,
        ex_date="2026-02-09",
        payment_date="2026-02-12",
        frequency="q",
    )

    next_item = pick_next_dividend([historical, announced], as_of=now)

    assert next_item is not None
    assert next_item.is_projected is False
    assert next_item.ex_date == "2026-06-10"


def test_enrich_dividend_dates_fills_missing_payment_from_median_lag():
    dividends = [
        GlobalStockDividend(
            date="2026-06-15",
            amount=0.53,
            ex_date="2026-06-15",
            payment_date="2026-07-01",
        ),
        GlobalStockDividend(
            date="2026-03-13",
            amount=0.53,
            ex_date="2026-03-13",
            payment_date="2026-04-01",
        ),
        GlobalStockDividend(
            date="2026-05-21",
            amount=0.91,
            ex_date="2026-05-21",
        ),
    ]

    enriched = enrich_dividend_dates(dividends)

    assert enriched[2].payment_date == "2026-06-06"


def test_enrich_dividend_dates_skips_estimate_without_lag_history():
    dividends = [
        GlobalStockDividend(date="2025-05-12", amount=0.26, ex_date="2025-05-12"),
    ]

    enriched = enrich_dividend_dates(dividends)

    assert enriched[0].payment_date is None


def test_project_next_dividend_uses_quarterly_interval():
    now = datetime(2026, 5, 25, tzinfo=UTC)
    dividends = [
        GlobalStockDividend(
            date="2026-02-09",
            amount=0.26,
            ex_date="2026-02-09",
            payment_date="2026-02-12",
            frequency="q",
        )
    ]

    projected = project_next_dividend(dividends, as_of=now)

    assert projected is not None
    assert projected.is_projected is True
    assert projected.ex_date == "2026-08-10"
    assert projected.payment_date == "2026-08-13"
