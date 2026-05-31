from app.clients.marketstack.stock_mapper import (
    map_eod_quotes_with_change,
    map_exchange,
    normalize_marketstack_symbol,
    resolve_catalog_symbol,
    us_logo_source_url,
)


def test_us_logo_source_url_maps_exchange_suffix():
    base = "https://financialmodelingprep.com/image-stock/"
    # Listagens internacionais usam o sufixo da FMP, não o MIC da Marketstack.
    assert us_logo_source_url("SAP.XETRA") == f"{base}SAP.DE.png"
    assert us_logo_source_url("RY.XTSE") == f"{base}RY.TO.png"
    assert us_logo_source_url("AZN.XLON") == f"{base}AZN.L.png"
    assert us_logo_source_url("MC.XPAR") == f"{base}MC.PA.png"
    # Classe de ação US mantém o ponto.
    assert us_logo_source_url("BRK.B") == f"{base}BRK.B.png"
    assert us_logo_source_url("BRK-B") == f"{base}BRK.B.png"
    # Ticker simples (ADR / US) permanece igual.
    assert us_logo_source_url("TM") == f"{base}TM.png"
    # MIC desconhecido cai para o ticker base.
    assert us_logo_source_url("FOO.XUNKNOWN") == f"{base}FOO.png"


def test_normalize_marketstack_symbol():
    assert normalize_marketstack_symbol("brk.b") == "BRK-B"
    assert normalize_marketstack_symbol("AAPL") == "AAPL"
    assert normalize_marketstack_symbol("MSF.XETRA") == "MSF.XETRA"
    assert normalize_marketstack_symbol("RY.XTSE") == "RY.XTSE"


def test_resolve_catalog_symbol():
    catalog = ["AAPL", "BRK.B", "MSFT"]
    assert resolve_catalog_symbol("BRK-B", catalog) == "BRK.B"
    assert resolve_catalog_symbol("AAPL", catalog) == "AAPL"


def test_map_eod_quotes_with_change():
    rows = [
        {"symbol": "AAPL", "close": 110.0, "date": "2025-05-02T00:00:00+0000"},
        {"symbol": "AAPL", "close": 100.0, "date": "2025-05-01T00:00:00+0000"},
    ]
    quotes = map_eod_quotes_with_change(rows, category="stocks")
    assert len(quotes) == 1
    assert quotes[0].symbol == "AAPL"
    assert quotes[0].price == 110.0
    assert quotes[0].change_percent == 10.0
    assert quotes[0].provider == "marketstack"


def test_map_exchange():
    exchange = map_exchange(
        {
            "name": "NASDAQ",
            "mic": "XNAS",
            "country": "United States",
            "country_code": "US",
            "city": "New York",
        }
    )
    assert exchange is not None
    assert exchange.mic == "XNAS"
    assert exchange.country_code == "US"
