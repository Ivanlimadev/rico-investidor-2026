from app.clients.brapi.models import StockDividendsResponse, StockDividendsSummary, StockFundamentals
from app.domain.fii.models import FiiDetail
from app.services.br_proventos_service import BrProventosService


def test_merge_dividend_yield_into_fundamentals():
    fundamentals = StockFundamentals(dividend_yield_12m=1.0)
    dividends = StockDividendsResponse(
        ticker="PETR4",
        count=0,
        dividend_yield_ttm=5.65,
        summary=StockDividendsSummary(dividend_yield_display=6.97),
    )
    merged = BrProventosService.merge_dividend_yield_into_fundamentals(fundamentals, dividends)
    assert merged.dividend_yield_12m == 6.97
