from app.clients.brapi.stock_mapper import map_stock_fundamental_history, passes_fundamental_filters
from app.clients.brapi.models import StockScreenerItem


def test_map_stock_fundamental_history():
    result = map_stock_fundamental_history(
        ticker="PETR4",
        item={
            "financialDataHistoryQuarterly": [
                {
                    "endDate": "2025-12-31",
                    "totalRevenue": 100.0,
                    "ebitda": 40.0,
                    "freeCashflow": 20.0,
                    "profitMargins": 0.18,
                    "returnOnEquity": 0.22,
                }
            ],
            "defaultKeyStatisticsHistoryQuarterly": [
                {
                    "endDate": "2025-12-31",
                    "netIncomeToCommon": 18.0,
                    "trailingPE": 6.5,
                    "priceToBook": 1.1,
                    "dividendYield": 0.08,
                }
            ],
        },
        limit=4,
    )

    assert result.ticker == "PETR4"
    assert result.count == 1
    period = result.periods[0]
    assert period.total_revenue == 100.0
    assert period.net_income == 18.0
    assert period.profit_margin == 18.0
    assert period.return_on_equity == 22.0
    assert period.dividend_yield_12m == 8.0


def test_passes_fundamental_filters():
    item = StockScreenerItem(
        symbol="PETR4",
        name="Petrobras",
        price=40.0,
        change_percent=1.0,
        category="acoes_br",
        dividend_yield_12m=8.0,
        price_earnings=6.0,
        return_on_equity=20.0,
        price_to_book=1.2,
    )

    assert passes_fundamental_filters(item, min_dividend_yield=6.0, max_price_earnings=10.0)
    assert not passes_fundamental_filters(item, min_dividend_yield=10.0)
