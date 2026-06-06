import asyncio
from datetime import date
from unittest.mock import AsyncMock

from app.clients.bolsai.models import BolsaiDividendPayment, BolsaiDividendsResponse
from app.clients.brapi.models import (
    MarketQuote,
    StockDividendsResponse,
    StockFundamentals,
    StockMarketStats,
    StockProfile,
)
from app.domain.fii.models import FiiDistributionPayment
from app.services.br_proventos_service import BrProventosService
from app.services.quote_service import QuoteService, _DetailFastBundle, _DetailSlowBundle


def test_stock_dividends_from_bolsai_when_configured():
    bolsai = AsyncMock()
    bolsai.configured = True
    bolsai.get_dividends.return_value = BolsaiDividendsResponse(
        ticker="PETR4",
        dividend_yield_ttm=5.65,
        payments=[
            BolsaiDividendPayment(
                ex_date="2026-06-02",
                payment_date="2026-08-20",
                type="JCP",
                value_per_share=0.35,
            ),
        ],
    )
    bolsai.get_fundamentals = AsyncMock(return_value=None)
    bolsai.get_company = AsyncMock(return_value=None)
    brapi = AsyncMock()
    brapi.get_stock_dividends.return_value = StockDividendsResponse(
        ticker="PETR4",
        count=0,
        corporate_actions=[],
    )

    service = BrProventosService(bolsai=bolsai, brapi=brapi)
    result = asyncio.run(service.get_stock_dividends("PETR4", limit=10))
    assert result.provider == "bolsai"
    assert result.payments[0].reference_date == "2026-06-01"
    bolsai.get_dividends.assert_awaited_once_with("PETR4")


def test_reconcile_market_quote_recomputes_display_dy_when_price_changes():
    bolsai = AsyncMock()
    bolsai.configured = True
    brapi = AsyncMock()
    service = BrProventosService(bolsai=bolsai, brapi=brapi)

    service.display_dividend_yield_for_price = AsyncMock(side_effect=lambda ticker, price, limit=60: 3.5 if price == 10.0 else 4.0)
    service.get_fundamentals_cached = AsyncMock(return_value={"pl": 12.3})
    service.get_bolsai_quote_cached = AsyncMock(return_value={"close": 11.0, "previous_close": 10.5})

    quote = MarketQuote(
        symbol="PETR4",
        name="Petrobras",
        price=10.0,
        change_percent=0.0,
        category="acoes_br",
    )

    result = asyncio.run(service.reconcile_market_quote(quote))

    assert result.price == 11.0
    assert result.dividend_yield_12m == 4.0
    assert service.display_dividend_yield_for_price.await_count == 2
    service.display_dividend_yield_for_price.assert_any_await("PETR4", price=10.0)
    service.display_dividend_yield_for_price.assert_any_await("PETR4", price=11.0)


def test_enrich_fii_detail_prefers_bolsai_close_price_and_dy():
    bolsai = AsyncMock()
    bolsai.configured = True
    payload = type("Payload", (), {"dividend_yield_ttm": 8.0, "close_price": 105.0})
    bolsai.get_fii_distributions = AsyncMock(return_value=payload)

    brapi = AsyncMock()
    service = BrProventosService(bolsai=bolsai, brapi=brapi)

    from app.domain.fii.models import FiiDetail

    detail = FiiDetail(
        ticker="KNRI11",
        name="Kinea Renda Imobiliária",
        close_price=100.0,
        dividend_yield_ttm=7.5,
    )

    result = asyncio.run(service.enrich_fii_detail(detail))

    assert result.close_price == 105.0
    assert result.dividend_yield_ttm == 8.0


def test_merge_detail_bundles_recomputes_dy_after_bolsai_price_patch():
    quote = MarketQuote(
        symbol="PETR4",
        name="Petrobras",
        price=10.0,
        change_percent=0.0,
        category="acoes_br",
    )
    fast = _DetailFastBundle(
        quote=quote,
        market_stats=StockMarketStats(),
        profile=StockProfile(),
        fundamentals=StockFundamentals(),
        candles=(),
    )
    slow = _DetailSlowBundle(
        dividends=StockDividendsResponse(
            ticker="PETR4",
            count=1,
            payments=[
                FiiDistributionPayment(
                    reference_date=date.today().isoformat(),
                    payment_date=date.today().isoformat(),
                    value_per_share=0.60,
                )
            ],
        ),
        fundamentals=StockFundamentals(),
        market_stats=StockMarketStats(),
        profile=StockProfile(),
        quote_name=None,
        provider="bolsai",
        bolsai_quote={"close": 11.0},
        bolsai_fundamentals=None,
    )

    service = QuoteService()
    merged = service._merge_detail_bundles(fast, slow)

    assert merged.quote.price == 11.0
    assert merged.dividends.summary.dividend_yield_display == 5.45
