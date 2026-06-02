from app.domain.global_markets.us_dividend_dates import investidor10_com_date, normalize_us_market_day


def test_investidor10_com_date_is_previous_us_business_day():
    assert investidor10_com_date("2026-06-15") == "2026-06-12"
    assert investidor10_com_date("2026-03-13") == "2026-03-12"
    assert investidor10_com_date("2025-12-01") == "2025-11-28"


def test_normalize_us_market_day_uses_eastern_calendar():
    assert normalize_us_market_day("2026-07-01 04:00:00") == "2026-07-01"
    assert normalize_us_market_day("2026-02-12 05:00:00") == "2026-02-12"
    assert normalize_us_market_day("2026-05-11") == "2026-05-11"
