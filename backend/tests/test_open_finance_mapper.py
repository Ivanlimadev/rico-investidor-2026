import pytest

from app.services.open_finance_service import _map_investment, _resolve_symbol


def test_map_equity_fii_investment():
    mapped = _map_investment(
        {
            "id": "abc-123",
            "itemId": "item-1",
            "type": "EQUITY",
            "subtype": "REAL_ESTATE_FUND",
            "name": "CSHG Logística FII · HGLG11",
            "code": "HGLG11",
            "balance": 4873.5,
            "quantity": 30,
            "value": 162.45,
            "amountOriginal": 4740,
            "currencyCode": "BRL",
            "date": "2026-02-28T00:00:00.000Z",
            "status": "ACTIVE",
        },
        institution="XP Investimentos",
    )

    assert mapped is not None
    assert mapped["symbol"] == "HGLG11"
    assert mapped["quantity"] == 30
    assert mapped["source"] == "open_finance"


def test_map_fixed_income_without_quantity():
    mapped = _map_investment(
        {
            "id": "cdb-1",
            "itemId": "item-1",
            "type": "FIXED_INCOME",
            "subtype": "CDB",
            "name": "CDB Banco Exemplo",
            "balance": 2500,
            "amountOriginal": 2000,
            "currencyCode": "BRL",
            "date": "2026-02-28T00:00:00.000Z",
            "status": "ACTIVE",
        },
        institution="Nubank",
    )

    assert mapped is not None
    assert mapped["quantity"] == 1
    assert mapped["current_price"] == 2500


def test_resolve_symbol_from_name():
    assert _resolve_symbol({"id": "x"}, "Fundo MXRF11 renda") == "MXRF11"
