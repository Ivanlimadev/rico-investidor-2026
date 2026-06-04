from app.clients.brapi.models import StockFundamentals
from app.domain.global_markets.fundamentals import merge_fundamentals
from app.domain.global_markets.models import GlobalStockDividendsSummary


def test_merge_fundamentals_uses_dividend_summary_when_tickerinfo_missing():
    summary = GlobalStockDividendsSummary(dividend_yield_ttm=2.5, payments_12m=2)

    fundamentals = merge_fundamentals(tickerinfo=None, dividends_summary=summary)

    assert fundamentals.dividend_yield_12m == 2.5
    assert fundamentals.provider == "marketstack"


def test_merge_fundamentals_prefers_tickerinfo_yield():
    summary = GlobalStockDividendsSummary(dividend_yield_ttm=2.5)
    tickerinfo = {"statistics": {"dividendYield": 0.018}}

    fundamentals = merge_fundamentals(tickerinfo=tickerinfo, dividends_summary=summary)

    assert fundamentals.dividend_yield_12m == 1.8


def test_merge_fundamentals_maps_pe_ratio():
    tickerinfo = {"pe_ratio": 28.4}

    fundamentals = merge_fundamentals(
        tickerinfo=tickerinfo,
        dividends_summary=GlobalStockDividendsSummary(),
    )

    assert fundamentals.price_earnings == 28.4
    assert isinstance(fundamentals, StockFundamentals)
