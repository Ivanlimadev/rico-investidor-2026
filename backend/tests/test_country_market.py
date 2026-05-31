from app.domain.global_markets.presets import country_display_name, country_exchange_segments, country_hub_preset, country_hub_preset


def test_country_display_name_pt():
    assert country_display_name("DE") == "Alemanha"
    assert country_display_name("US") == "Estados Unidos"
    assert country_display_name("XX", "Unknown") == "Unknown"


def test_country_hub_preset_us():
    preset = country_hub_preset("US")
    assert "AAPL" in preset.featured
    assert "NVDA" in preset.tech
    assert "KO" in preset.dividends


def test_country_hub_preset_unknown_country():
    preset = country_hub_preset("ZZ")
    assert preset.featured == ()
    assert preset.tech == ()


def test_country_exchange_segments_preset():
    segments = country_exchange_segments("JP")
    assert segments
    assert segments[0][0] == "XTKS"


def test_country_exchange_segments_germany_uses_xetra():
    segments = country_exchange_segments("DE")
    assert segments[0][0] == "XETRA"
