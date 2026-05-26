from app.clients.brapi.stock_mapper import map_stock_dividends, normalize_candle_range


def test_normalize_candle_range():
    assert normalize_candle_range("ytd", limit=252) == "ytd"
    assert normalize_candle_range("MAX", limit=30) == "max"
    assert normalize_candle_range(None, limit=30) == "1mo"
    assert normalize_candle_range("invalid", limit=252) == "1y"


def test_normalize_sort_by():
    from app.clients.brapi.stock_mapper import normalize_sort_by

    assert normalize_sort_by("market_cap") == "market_cap_basic"
    assert normalize_sort_by("volume") == "volume"
    assert normalize_sort_by("unknown") == "volume"


def test_map_screener_item():
    from app.clients.brapi.stock_mapper import map_screener_item

    item = map_screener_item(
        {
            "stock": "PETR4",
            "name": "Petrobras",
            "close": 43.44,
            "change": 0.09,
            "volume": 36040500,
            "market_cap": 592871138983,
            "sector": "Energy Minerals",
            "type": "stock",
            "logo": "https://icons.brapi.dev/icons/PETR4.svg",
        }
    )

    assert item.symbol == "PETR4"
    assert item.sector == "Energy Minerals"
    assert item.market_cap == 592871138983
    assert item.logo_url.endswith("PETR4.svg")


def test_map_stock_compare_item():
    from app.clients.brapi.stock_mapper import map_stock_compare_item

    item = map_stock_compare_item(
        {
            "symbol": "PETR4",
            "longName": "Petrobras",
            "regularMarketPrice": 43.44,
            "regularMarketChangePercent": 0.09,
            "type": "stock",
            "summaryProfile": {"sector": "Energy Minerals"},
            "financialData": {"returnOnEquity": 0.24},
            "defaultKeyStatistics": {"dividendYield": 0.07, "trailingPE": 5.2},
            "marketCap": 1000,
        }
    )

    assert item.quote.symbol == "PETR4"
    assert item.fundamentals.dividend_yield_12m == 7.0
    assert item.profile.sector == "Energy Minerals"


def test_map_stock_financials():
    from app.clients.brapi.stock_mapper import map_stock_financials

    item = {
        "incomeStatementHistoryQuarterly": [
            {
                "endDate": "2026-03-31",
                "totalRevenue": 1000,
                "costOfRevenue": -400,
                "grossProfit": 600,
                "netIncome": 120,
            }
        ],
        "balanceSheetHistoryQuarterly": [
            {
                "endDate": "2026-03-31",
                "totalAssets": 5000,
                "totalStockholderEquity": 2000,
            }
        ],
        "cashflowHistoryQuarterly": [
            {
                "endDate": "2026-03-31",
                "operatingCashFlow": 300,
                "freeCashFlow": 150,
            }
        ],
    }

    result = map_stock_financials(ticker="PETR4", item=item, limit=4)
    assert result.ticker == "PETR4"
    assert result.income_statement[0].end_date == "2026-03-31"
    cpv = next(line for line in result.income_statement[0].lines if line.key == "cost_of_revenue")
    assert cpv.value == 400
    assert result.balance_sheet[0].lines[0].value == 5000
    assert result.cash_flow[0].lines[-1].key == "final_cash_balance"


def test_map_stock_dividends_builds_annual_summary_and_labels():
    data = {
        "cashDividends": [
            {
                "rate": 1.0,
                "lastDatePrior": "2024-03-10T03:00:00.000Z",
                "paymentDate": "2024-03-25T03:00:00.000Z",
                "label": "DIVIDENDO",
            },
            {
                "rate": 0.5,
                "lastDatePrior": "2024-06-10T03:00:00.000Z",
                "paymentDate": "2024-06-25T03:00:00.000Z",
                "label": "JCP",
            },
            {
                "rate": 0.25,
                "lastDatePrior": "2023-12-01T03:00:00.000Z",
                "paymentDate": "2023-12-15T03:00:00.000Z",
                "label": "RENDIMENTO",
            },
        ],
        "stockDividends": [
            {
                "label": "DESDOBRAMENTO",
                "factor": 2,
                "completeFactor": "2 para 1",
                "lastDatePrior": "2008-04-25T03:00:00.000Z",
            }
        ],
    }

    result = map_stock_dividends(ticker="PETR4", dividends_data=data, limit=10)

    assert result.count == 3
    assert result.total_payments == 3
    assert result.ttm_per_share == 1.75
    assert len(result.annual_summary) == 2
    assert result.annual_summary[0].year == 2024
    assert result.annual_summary[0].total_per_share == 1.5
    labels = {payment.label for payment in result.payments}
    assert labels == {"Dividendo", "Jcp", "Rendimento"}
    assert len(result.corporate_actions) == 1
    assert result.corporate_actions[0].complete_factor == "2 para 1"
