from app.domain.quotes.category_map import is_international_etf


def test_is_international_etf():
    assert is_international_etf("IVVB11")
    assert is_international_etf("BOVV11")
    assert not is_international_etf("BOVA11")
    assert not is_international_etf("PETR4")
