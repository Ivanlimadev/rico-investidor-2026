from app.domain.fii.ticker import is_valid_fii_ticker, normalize_fii_ticker


def test_normalize_full_ticker():
    assert normalize_fii_ticker("hglg11") == "HGLG11"


def test_normalize_short_ticker():
    assert normalize_fii_ticker("HGLG") == "HGLG11"


def test_is_valid_fii_ticker():
    assert is_valid_fii_ticker("MXRF11") is True
    assert is_valid_fii_ticker("PETR4") is False
