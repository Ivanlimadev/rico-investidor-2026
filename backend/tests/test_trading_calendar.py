from datetime import date

from app.domain.market_calendar.trading_calendar import previous_trading_day


def test_previous_trading_day_br_skips_weekend_and_holiday():
    # Ex 2026-04-23 (quinta); 21/04 é feriado (Tiradentes)
    assert previous_trading_day(date(2026, 4, 23), market="br") == date(2026, 4, 22)


def test_previous_trading_day_us_skips_weekend_and_juneteenth_observed():
    # Ex segunda 2026-06-15 → sexta 2026-06-12
    assert previous_trading_day(date(2026, 6, 15), market="us") == date(2026, 6, 12)
