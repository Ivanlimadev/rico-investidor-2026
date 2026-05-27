from app.clients.brapi.stock_mapper import map_stock_dividends, normalize_candle_range


def test_normalize_candle_range():
    assert normalize_candle_range("ytd", limit=252) == "ytd"
    assert normalize_candle_range("1d", limit=252) == "1d"
    assert normalize_candle_range("5d", limit=252) == "5d"
    assert normalize_candle_range("MAX", limit=30) == "max"
    assert normalize_candle_range(None, limit=30) == "1mo"
    assert normalize_candle_range("invalid", limit=252) == "1y"


def test_map_stock_candles_intraday_timestamp():
    from app.clients.brapi.stock_mapper import map_stock_candles

    result = map_stock_candles(
        ticker="PETR4",
        price_points=[
            {
                "date": 1748260500,
                "open": 43.0,
                "high": 43.5,
                "low": 42.9,
                "close": 43.2,
                "volume": 1000,
            }
        ],
        interval="5m",
        range_="1d",
    )

    assert result.interval == "5m"
    assert result.range == "1d"
    assert "T" in result.candles[0].trade_date


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


def test_map_stock_fundamentals_expanded_fields():
    from app.clients.brapi.stock_mapper import map_stock_fundamentals

    item = map_stock_fundamentals(
        {
            "priceEarnings": 5.2,
            "financialData": {
                "totalRevenue": 500_000_000_000,
                "ebitda": 120_000_000_000,
                "grossMargins": 0.42,
                "operatingMargins": 0.28,
                "revenueGrowth": 0.05,
                "totalCash": 80_000_000_000,
                "totalDebt": 200_000_000_000,
                "currentRatio": 1.2,
                "targetMeanPrice": 48.5,
                "recommendationKey": "buy",
                "numberOfAnalystOpinions": 14,
            },
            "defaultKeyStatistics": {
                "enterpriseValue": 600_000_000_000,
                "enterpriseToEbitda": 5.0,
                "forwardPE": 4.8,
            },
        }
    )

    assert item.total_revenue == 500_000_000_000
    assert item.ebitda == 120_000_000_000
    assert item.enterprise_value == 600_000_000_000
    assert item.forward_pe == 4.8
    assert item.gross_margin == 42.0
    assert item.recommendation_key == "buy"
    assert item.number_of_analyst_opinions == 14


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
        "valueAddedHistoryQuarterly": [
            {
                "endDate": "2026-03-31",
                "revenue": 1000,
                "suppliesPurchasedFromThirdParties": -400,
                "grossAddedValue": 600,
                "netAddedValue": 500,
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
    assert result.value_added[0].lines[0].value == 1000
    supplies = next(line for line in result.value_added[0].lines if line.key == "supplies_purchased")
    assert supplies.value == 400


def test_map_stock_performance():
    from app.domain.fii.models import FiiCandleBar
    from app.clients.brapi.stock_mapper import map_stock_performance

    ticker_candles = [
        FiiCandleBar(trade_date="2026-01-02", open=10, high=10, low=10, close=10),
        FiiCandleBar(trade_date="2026-01-03", open=11, high=11, low=11, close=11),
    ]
    benchmark_candles = [
        FiiCandleBar(trade_date="2026-01-02", open=100, high=100, low=100, close=100),
        FiiCandleBar(trade_date="2026-01-03", open=102, high=102, low=102, close=102),
    ]

    result = map_stock_performance(
        ticker="PETR4",
        benchmark="^BVSP",
        range_="1y",
        ticker_candles=ticker_candles,
        benchmark_candles=benchmark_candles,
    )

    assert result.benchmark_label == "IBOV"
    assert result.count == 2
    assert result.ticker_return_pct == 10.0
    assert result.benchmark_return_pct == 2.0


def test_map_stock_financials_annual():
    from app.clients.brapi.stock_mapper import map_stock_financials

    item = {
        "incomeStatementHistory": [
            {
                "endDate": "2025-12-31",
                "totalRevenue": 4000,
                "netIncome": 500,
            }
        ],
        "balanceSheetHistory": [
            {
                "endDate": "2025-12-31",
                "totalAssets": 9000,
            }
        ],
        "cashflowHistory": [
            {
                "endDate": "2025-12-31",
                "freeCashFlow": 300,
            }
        ],
    }

    result = map_stock_financials(ticker="PETR4", item=item, limit=4, period="annual")
    assert result.period == "annual"
    assert result.income_statement[0].end_date == "2025-12-31"
    assert result.income_statement[0].lines[0].value == 4000


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


def test_map_market_quote_includes_logo_fallback():
    from app.clients.brapi.stock_mapper import map_market_quote

    item = map_market_quote(
        {
            "symbol": "PETR4",
            "longName": "Petrobras",
            "regularMarketPrice": 38.42,
            "regularMarketChangePercent": 1.24,
            "type": "stock",
        }
    )

    assert item.logo_url == (
        "https://raw.githubusercontent.com/thefintz/icones-b3/main/icones/PETR4.png"
    )


def test_map_enriched_market_quote():
    from app.clients.brapi.stock_mapper import map_enriched_market_quote

    item = map_enriched_market_quote(
        {
            "symbol": "PETR4",
            "longName": "Petrobras PN",
            "regularMarketPrice": 38.42,
            "regularMarketChangePercent": 1.24,
            "type": "stock",
            "logourl": "https://icons.brapi.dev/icons/PETR4.svg",
            "defaultKeyStatistics": {
                "dividendYield": 0.125,
                "priceToBook": 0.98,
            },
        }
    )

    assert item.symbol == "PETR4"
    assert item.dividend_yield_12m == 12.5
    assert item.price_to_book == 0.98
    assert item.logo_url == (
        "https://raw.githubusercontent.com/thefintz/icones-b3/main/icones/PETR4.png"
    )
