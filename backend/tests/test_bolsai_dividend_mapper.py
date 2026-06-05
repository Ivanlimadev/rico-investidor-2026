from app.clients.bolsai.models import BolsaiDividendPayment, BolsaiDividendsResponse
from app.clients.bolsai.proventos_mapper import map_bolsai_stock_dividends


def test_map_bolsai_stock_dividends_uses_investidor10_com_date():
    payload = BolsaiDividendsResponse(
        ticker="PETR4",
        dividend_yield_ttm=5.65,
        payments=[
            BolsaiDividendPayment(
                ex_date="2026-06-02",
                payment_date="2026-08-20",
                type="JCP",
                value_per_share=0.350486,
            ),
        ],
    )
    result = map_bolsai_stock_dividends(payload, limit=10)
    assert result.provider == "bolsai"
    assert len(result.payments) == 1
    assert result.payments[0].reference_date == "2026-06-01"
    assert result.payments[0].payment_date == "2026-08-20"
    assert result.payments[0].label == "Jcp"
    assert result.payments[0].value_per_share == 0.350486
    assert result.dividend_yield_ttm == 5.65


def test_map_bolsai_fii_distributions_uses_reference_date():
    from app.clients.bolsai.proventos_mapper import map_bolsai_fii_distributions

    payload = BolsaiDividendsResponse(
        ticker="HGLG11",
        name="CSHG Logística",
        payments=[
            BolsaiDividendPayment(
                reference_date="2026-04-01",
                value_per_share=1.0784,
            ),
        ],
    )
    result = map_bolsai_fii_distributions(payload, years=5)
    assert result.provider == "bolsai"
    assert result.payments[0].reference_date == "2026-04-01"
