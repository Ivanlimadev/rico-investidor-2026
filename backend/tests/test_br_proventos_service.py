import asyncio
from unittest.mock import AsyncMock

from app.clients.bolsai.models import BolsaiDividendPayment, BolsaiDividendsResponse
from app.clients.brapi.models import StockDividendsResponse
from app.services.br_proventos_service import BrProventosService


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
