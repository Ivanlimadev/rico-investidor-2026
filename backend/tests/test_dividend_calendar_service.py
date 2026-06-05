import asyncio
from datetime import date
from unittest.mock import AsyncMock

from app.clients.brapi.models import StockDividendsResponse
from app.domain.dividends.calendar_models import DividendCalendarEntry
from app.domain.fii.models import FiiDistributionPayment
from app.services.br_proventos_service import BrProventosService
from app.services.dividend_calendar_service import DividendCalendarService


def _br_entry(**kwargs) -> DividendCalendarEntry:
    base = {
        "market": "br",
        "symbol": "PETR4",
        "company_name": "Petrobras",
        "exchange": "B3",
        "dividend_type": "Jcp",
        "com_date": "2026-06-02",
        "payment_date": "2026-08-20",
        "amount": 0.35,
        "currency": "BRL",
    }
    base.update(kwargs)
    return DividendCalendarEntry(**base)


def test_br_calendar_uses_proventos_when_bolsai_configured(monkeypatch):
    proventos = AsyncMock(spec=BrProventosService)
    proventos.uses_bolsai = True
    proventos.fetch_company_names_batch.return_value = {"PETR4": "Petrobras"}
    proventos.get_stock_dividends.return_value = StockDividendsResponse(
        ticker="PETR4",
        name="Petrobras",
        count=1,
        payments=[
            FiiDistributionPayment(
                reference_date="2026-06-02",
                payment_date="2026-08-20",
                value_per_share=0.35,
                label="Jcp",
            ),
        ],
        provider="bolsai",
    )

    brapi = AsyncMock()
    brapi.get_quotes_raw.return_value = [
        {"symbol": "PETR4", "shortName": "Petrobras"},
    ]

    service = DividendCalendarService(brapi=brapi, proventos=proventos, marketstack=AsyncMock())
    monkeypatch.setattr(
        "app.services.dividend_calendar_service.filter_upcoming_entries",
        lambda entries, **_: entries,
    )
    monkeypatch.setattr(
        "app.services.dividend_calendar_service.date",
        type("D", (), {"today": staticmethod(lambda: date(2026, 6, 2))})(),
    )

    response = asyncio.run(service.get_calendar(market="br", days_ahead=120))
    assert "bolsai" in response.data_sources
    petr = [item for item in response.items if item.symbol == "PETR4"]
    assert any(item.com_date == "2026-06-02" and item.amount == 0.35 for item in petr)
    assert proventos.get_stock_dividends.await_count >= 1


def test_br_calendar_serves_stale_while_rebuilding(monkeypatch):
    proventos = AsyncMock(spec=BrProventosService)
    proventos.uses_bolsai = True
    proventos.fetch_company_names_batch.return_value = {"PETR4": "Petrobras"}
    proventos.get_stock_dividends.return_value = StockDividendsResponse(
        ticker="PETR4",
        name="Petrobras",
        count=1,
        payments=[],
        provider="bolsai",
    )

    service = DividendCalendarService(brapi=AsyncMock(), proventos=proventos, marketstack=AsyncMock())
    monkeypatch.setattr(
        "app.services.dividend_calendar_service.filter_upcoming_entries",
        lambda entries, **_: entries,
    )
    monkeypatch.setattr(
        "app.services.dividend_calendar_service.load_br_dividend_calendar_tickers",
        AsyncMock(return_value=("PETR4",)),
    )

    first = asyncio.run(service.get_calendar(market="br"))
    assert first.count == 0

    service._br_snapshot_cache._store.clear()
    proventos.get_stock_dividends.reset_mock()

    second = asyncio.run(service.get_calendar(market="br"))
    assert second.count == 0
    assert proventos.get_stock_dividends.await_count == 0
