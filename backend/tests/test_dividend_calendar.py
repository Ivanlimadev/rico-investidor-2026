from datetime import date

from app.domain.dividends.calendar_builder import (
    filter_upcoming_entries,
    sort_calendar_entries,
)
from app.domain.dividends.calendar_models import DividendCalendarEntry


def _entry(**kwargs) -> DividendCalendarEntry:
    base = {
        "market": "br",
        "symbol": "PETR4",
        "company_name": "Petrobras",
        "com_date": "2026-06-01",
        "payment_date": "2026-06-15",
        "amount": 1.5,
        "currency": "BRL",
    }
    base.update(kwargs)
    return DividendCalendarEntry(**base)


def test_filter_upcoming_by_payment_date():
    today = date(2026, 6, 1)
    items = [
        _entry(com_date="2026-04-01", payment_date="2026-05-01"),
        _entry(symbol="VALE3", payment_date="2026-06-20"),
        _entry(symbol="ITUB4", payment_date=None, com_date="2026-06-10"),
    ]
    filtered = filter_upcoming_entries(items, days_ahead=60, today=today)
    symbols = {item.symbol for item in filtered}
    assert "PETR4" not in symbols
    assert symbols == {"VALE3", "ITUB4"}


def test_filter_includes_future_com_or_payment():
    today = date(2026, 6, 1)
    items = [
        _entry(com_date="2026-06-01", payment_date="2026-08-20", amount=0.35),
        _entry(com_date="2026-04-22", payment_date="2026-06-22", amount=0.013, dividend_type="Rendimento"),
        _entry(symbol="VALE3", com_date="2026-03-01", payment_date="2026-04-01"),
    ]
    filtered = filter_upcoming_entries(items, days_ahead=120, today=today)
    symbols = {item.symbol for item in filtered}
    assert symbols == {"PETR4"}
    assert len(filtered) == 2


def test_sort_by_payment_then_com():
    items = [
        _entry(symbol="BBAS3", com_date="2026-06-01", payment_date="2026-06-25"),
        _entry(symbol="ITUB4", com_date="2026-06-02", payment_date="2026-06-10"),
    ]
    sorted_items = sort_calendar_entries(items, sort_by="payment")
    assert [row.symbol for row in sorted_items] == ["ITUB4", "BBAS3"]
