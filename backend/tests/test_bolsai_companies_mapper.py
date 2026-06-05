from app.clients.bolsai.companies_mapper import company_display_name, merge_company_into_profile
from app.clients.brapi.models import StockProfile


def test_company_display_name_prefers_trade_name():
    payload = {
        "trade_name": "PETROBRAS",
        "corporate_name": "PETRÓLEO BRASILEIRO S.A.",
    }
    assert company_display_name(payload) == "PETROBRAS"


def test_merge_company_into_profile_fills_sector():
    profile = StockProfile(sector=None, country=None)
    company = {"sector": "Petróleo e Gás", "country": "BRASIL", "website": "https://petrobras.com.br"}
    merged = merge_company_into_profile(profile, company)
    assert merged.sector == "Petróleo e Gás"
    assert merged.country == "BRASIL"
    assert merged.website == "https://petrobras.com.br"
    assert merged.provider == "hybrid"
