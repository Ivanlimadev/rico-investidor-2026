from app.clients.bolsai.financials_mapper import map_bolsai_financials


def test_map_bolsai_financials_quarterly():
    payload = {
        "ticker": "PETR4",
        "report_type": "ITR",
        "statements": [
            {
                "reference_date": "2026-03-31",
                "statement_type": "DRE",
                "account_code": "3.01",
                "account_name": "Receita",
                "value": 123686000.0,
            },
            {
                "reference_date": "2026-03-31",
                "statement_type": "DRE",
                "account_code": "3.11",
                "account_name": "Lucro",
                "value": 32761000.0,
            },
            {
                "reference_date": "2026-03-31",
                "statement_type": "BPA",
                "account_code": "1",
                "account_name": "Ativo Total",
                "value": 1246068000.0,
            },
            {
                "reference_date": "2026-03-31",
                "statement_type": "BPP",
                "account_code": "2.03",
                "account_name": "PL",
                "value": 446372000.0,
            },
            {
                "reference_date": "2026-03-31",
                "statement_type": "DFC_MI",
                "account_code": "6.01",
                "account_name": "Caixa Op",
                "value": 43975000.0,
            },
            {
                "reference_date": "2026-03-31",
                "statement_type": "DFC_MI",
                "account_code": "6.02.01",
                "account_name": "Capex",
                "value": -12000000.0,
            },
            {
                "reference_date": "2026-03-31",
                "statement_type": "DVA",
                "account_code": "7.01",
                "account_name": "Receitas",
                "value": 191003000.0,
            },
        ],
    }
    result = map_bolsai_financials("PETR4", payload, limit=4, period="quarterly")
    assert result.provider == "bolsai"
    assert not result.is_empty()
    assert result.income_statement[0].lines[0].key == "total_revenue"
    assert result.income_statement[0].lines[0].value == 123686000.0
    assert result.balance_sheet[0].lines[0].key == "total_assets"
    assert result.cash_flow[0].lines[0].key == "operating_cash_flow"
    fcf = next(line for line in result.cash_flow[0].lines if line.key == "free_cash_flow")
    assert fcf.value == 31975000.0
    assert result.value_added[0].lines[0].key == "revenue"


def test_map_bolsai_financials_enriches_ebitda_from_history():
    payload = {
        "ticker": "PETR4",
        "report_type": "ITR",
        "statements": [
            {
                "reference_date": "2026-03-31",
                "statement_type": "DRE",
                "account_code": "3.05",
                "value": 50000.0,
            },
        ],
    }
    history = {
        "history": [
            {
                "reference_date": "2026-03-31",
                "ebit": 45000.0,
                "ebitda": 60000.0,
            }
        ]
    }
    result = map_bolsai_financials(
        "PETR4",
        payload,
        limit=4,
        period="quarterly",
        fundamentals_history=history,
    )
    keys = [line.key for line in result.income_statement[0].lines]
    assert keys.index("operating_income") < keys.index("ebit") < keys.index("ebitda")
    assert next(line for line in result.income_statement[0].lines if line.key == "ebitda").value == 60000.0
