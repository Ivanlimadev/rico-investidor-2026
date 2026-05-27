from app.clients.brapi.fii_mapper import map_fii_detail_from_brapi, pct_from_ratio


def test_map_fii_detail_from_brapi():
    indicators = {
        "name": "CSHG Logística",
        "price": 154.7,
        "navPerShare": 166.49,
        "priceToNav": 0.929,
        "dividendYield12m": 0.0853,
        "equity": 7_234_911_000,
        "sharesOutstanding": 43_455_524,
        "totalInvestors": 565_330,
        "segmentoAtuacao": "Logística",
        "tipoGestao": "Ativa",
        "administratorName": "Genial",
        "asOfDate": "2026-04-01",
    }
    report = {
        "referenceDate": "2026-04-01",
        "totalAssets": 100,
        "realEstateAssets": 80,
        "adminFeeRate": 0.000443,
    }

    detail = map_fii_detail_from_brapi(
        ticker="HGLG11",
        indicators=indicators,
        report=report,
    )

    assert detail.ticker == "HGLG11"
    assert detail.provider == "brapi"
    assert detail.close_price == 154.7
    assert detail.pvp == 0.929
    assert detail.dividend_yield_ttm == pct_from_ratio(0.0853)
    assert detail.asset_composition is not None
    assert detail.asset_composition.real_estate_leased_pct == 80.0
    assert detail.fees_paid_last_month is not None
