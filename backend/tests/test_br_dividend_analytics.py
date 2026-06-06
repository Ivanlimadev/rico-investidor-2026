from datetime import UTC, datetime

from app.domain.dividends.br_dividend_analytics import (
    build_br_dividends_summary,
    investidor10_dy_atual,
    payments_to_global_dividends,
    resolve_display_dividend_yield,
)
from app.domain.dividends.br_com_date import investidor10_br_com_date as com_from_ex
from app.domain.fii.models import FiiDistributionPayment, FiiDistributionYearSummary
from app.domain.global_markets.dividend_analytics import pick_next_dividend


def test_resolve_display_dividend_yield_preserves_zero():
    assert resolve_display_dividend_yield(
        dividend_yield_display=0.0,
        dividend_yield_ttm=7.65,
    ) == 0.0


def test_investidor10_dy_zero_when_no_payments_in_12m():
    as_of = datetime(2026, 6, 5, tzinfo=UTC)
    payments = [
        FiiDistributionPayment(
            reference_date="2024-08-21",
            payment_date="2024-11-21",
            value_per_share=0.33,
            label="Jcp",
        ),
    ]
    dy, ttm = investidor10_dy_atual(payments, price=10.52, as_of=as_of)
    assert dy == 0.0
    assert ttm == 0.0


def test_investidor10_dy_uses_paid_window():
    as_of = datetime(2026, 6, 5, tzinfo=UTC)
    payments = [
        FiiDistributionPayment(
            reference_date="2026-04-22",
            payment_date="2026-05-20",
            value_per_share=0.31,
            label="Jcp",
        ),
        FiiDistributionPayment(
            reference_date="2025-08-21",
            payment_date="2025-11-21",
            value_per_share=0.33,
            label="Jcp",
        ),
    ]
    dy, ttm = investidor10_dy_atual(payments, price=41.25, as_of=as_of)
    assert dy is not None
    assert ttm is not None
    assert dy > 0


def test_build_summary_includes_next_dividend():
    as_of = datetime(2026, 6, 5, tzinfo=UTC)
    payments = [
        FiiDistributionPayment(
            reference_date="2026-06-01",
            payment_date="2026-08-20",
            value_per_share=0.350486,
            label="Jcp",
        ),
        FiiDistributionPayment(
            reference_date="2026-04-22",
            payment_date="2026-05-20",
            value_per_share=0.313115,
            label="Jcp",
        ),
    ]
    annual = [
        FiiDistributionYearSummary(year=2025, total_per_share=2.92, payments=14),
        FiiDistributionYearSummary(year=2024, total_per_share=6.53, payments=19),
    ]
    summary = build_br_dividends_summary(payments, annual, price=41.25, as_of=as_of)
    assert summary["dividend_yield_display"] is not None
    assert summary["next_dividend"] is not None
    assert summary["next_dividend"]["com_date"] == "2026-06-01"


def test_payments_to_global_and_pick_announced():
    as_of = datetime(2026, 6, 5, tzinfo=UTC)
    payments = [
        FiiDistributionPayment(
            reference_date="2026-06-01",
            payment_date="2026-08-20",
            value_per_share=0.35,
            label="Jcp",
        ),
    ]
    rows = payments_to_global_dividends(payments)
    assert rows[0].com_date == "2026-06-01"
    assert com_from_ex(rows[0].ex_date) == "2026-06-01"
    next_item = pick_next_dividend(rows, as_of=as_of)
    assert next_item is not None
    assert next_item.is_projected is False
