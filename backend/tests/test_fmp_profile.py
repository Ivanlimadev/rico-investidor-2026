from app.clients.fmp.profile_mapper import fmp_company_updates, fmp_market_cap
from app.clients.marketstack.stock_mapper import fmp_api_symbol
from app.domain.global_markets.models import GlobalStockCompanyProfile


def _base_profile(**kwargs) -> GlobalStockCompanyProfile:
    defaults = {"symbol": "SAP.XETRA", "name": "SAP SE"}
    defaults.update(kwargs)
    return GlobalStockCompanyProfile(**defaults)


def test_fmp_company_updates_fills_only_missing_fields():
    profile = _base_profile(sector="Existing Sector")
    fmp = {
        "sector": "Technology",
        "industry": "Software",
        "description": "Enterprise software company.",
        "website": "https://sap.com",
        "country": "DE",
        "fullTimeEmployees": "107000",
    }

    enriched = fmp_company_updates(profile, fmp)

    # Não sobrescreve o que a Marketstack já trouxe.
    assert enriched.sector == "Existing Sector"
    # Preenche o que faltava.
    assert enriched.industry == "Software"
    assert enriched.summary == "Enterprise software company."
    assert enriched.website == "https://sap.com"
    assert enriched.country == "DE"
    assert enriched.employees == 107000


def test_fmp_company_updates_noop_when_no_profile():
    profile = _base_profile()
    assert fmp_company_updates(profile, None) is profile


def test_fmp_market_cap_parses_numeric():
    assert fmp_market_cap({"marketCap": 1234.5}) == 1234.5
    assert fmp_market_cap({"mktCap": "987"}) == 987.0
    assert fmp_market_cap(None) is None
    assert fmp_market_cap({}) is None


def test_fmp_api_symbol_translates_exchange_suffix():
    assert fmp_api_symbol("SAP.XETRA") == "SAP.DE"
    assert fmp_api_symbol("BRK.B") == "BRK.B"
    assert fmp_api_symbol("BRK-B") == "BRK.B"
    assert fmp_api_symbol("AAPL") == "AAPL"
