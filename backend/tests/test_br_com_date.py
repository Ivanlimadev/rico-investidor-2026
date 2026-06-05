from app.domain.dividends.br_com_date import investidor10_br_com_date


def test_investidor10_br_com_date_previous_business_day():
    assert investidor10_br_com_date("2026-06-02") == "2026-06-01"
    assert investidor10_br_com_date("2026-04-23") == "2026-04-22"
    assert investidor10_br_com_date("2026-06-15") == "2026-06-12"
