from app.clients.brapi.models import StockDividendsResponse
from app.domain.fii.models import FiiDistributionPayment, FiiDistributionYearSummary
from app.services.br_proventos_service import BrProventosService


def test_enrich_dividends_with_summary_sets_display_dy():
    dividends = StockDividendsResponse(
        ticker="PETR4",
        count=2,
        dividend_yield_ttm=5.65,
        payments=[
            FiiDistributionPayment(
                reference_date="2026-06-01",
                payment_date="2026-08-20",
                value_per_share=0.35,
                label="Jcp",
            ),
            FiiDistributionPayment(
                reference_date="2026-04-22",
                payment_date="2026-05-20",
                value_per_share=0.31,
                label="Jcp",
            ),
        ],
        annual_summary=[
            FiiDistributionYearSummary(year=2025, total_per_share=2.92, payments=14),
        ],
    )
    enriched = BrProventosService.enrich_dividends_with_summary(dividends, price=41.25)
    assert enriched.summary.dividend_yield_display is not None
    assert enriched.dividend_yield_ttm == 5.65
    assert enriched.summary.next_dividend is not None
    assert enriched.summary.next_dividend.com_date == "2026-06-01"
