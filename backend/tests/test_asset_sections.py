from app.domain.fii.models import FiiCandleBar
from app.clients.brapi.models import (
    MarketQuote,
    StockDividendsResponse,
    StockFundamentals,
    StockMarketStats,
    StockProfile,
    StockQuoteDetailResponse,
)
from app.domain.assets.sections import stock_notes, stock_sections
from app.providers.registry import AssetClass


def _etf_detail() -> StockQuoteDetailResponse:
    return StockQuoteDetailResponse(
        quote=MarketQuote(
            symbol="BOVA11",
            name="iShares Ibovespa",
            price=173.29,
            change_percent=-0.68,
            category="etf",
        ),
        market_stats=StockMarketStats(volume=1_000_000.0),
        profile=StockProfile(logo_url="https://icons.brapi.dev/icons/BOVA11.svg"),
        fundamentals=StockFundamentals(),
        candles=[
            FiiCandleBar(
                trade_date="2026-05-26",
                open=1.0,
                high=1.0,
                low=1.0,
                close=1.0,
                volume=1.0,
            )
        ],
        dividends=StockDividendsResponse(ticker="BOVA11", count=0),
    )


def _stock_detail() -> StockQuoteDetailResponse:
    return StockQuoteDetailResponse(
        quote=MarketQuote(
            symbol="PETR4",
            name="Petrobras",
            price=43.44,
            change_percent=0.09,
            category="acoes_br",
        ),
        market_stats=StockMarketStats(),
        profile=StockProfile(sector="Energia"),
        fundamentals=StockFundamentals(dividend_yield_12m=7.0, price_earnings=5.2),
        dividends=StockDividendsResponse(
            ticker="PETR4",
            count=2,
            payments=[{"payment_date": "2026-01-01", "value_per_share": 1.0}],  # type: ignore[list-item]
        ),
    )


def test_etf_sections_and_notes():
    detail = _etf_detail()
    sections = stock_sections(detail, AssetClass.ETF_BR)
    notes = stock_notes(detail, AssetClass.ETF_BR)

    assert sections == ["quote", "chart", "profile"]
    assert any("Histórico parcial" in note for note in notes)


def test_stock_sections_include_fundamentals():
    detail = _stock_detail()
    sections = stock_sections(detail, AssetClass.STOCK_BR)

    assert "fundamentals" in sections
    assert "dividends" in sections
    assert "financials" in sections
