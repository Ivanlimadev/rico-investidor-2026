from app.domain.dividends.calendar_merge import merge_br_dividend_entries
from app.domain.dividends.calendar_models import DividendCalendarEntry


def _br(**kwargs) -> DividendCalendarEntry:
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


def test_merge_prefers_bolsai_and_keeps_brapi_only_rows():
    bolsai = [_br()]
    brapi = [
        _br(),  # duplicate
        _br(
            com_date="2026-04-22",
            payment_date="2026-06-22",
            dividend_type="Rendimento",
            amount=0.013,
        ),
    ]
    merged = merge_br_dividend_entries(bolsai=bolsai, brapi=brapi)
    assert len(merged) == 2
    assert merged[0].com_date == "2026-06-02"
    assert merged[1].dividend_type == "Rendimento"
