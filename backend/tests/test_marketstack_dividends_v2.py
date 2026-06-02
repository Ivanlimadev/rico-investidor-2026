from app.clients.marketstack.client import MarketstackClient


def test_dividends_base_url_upgrades_v1_to_v2():
    assert (
        MarketstackClient.resolve_v2_base_url("https://api.marketstack.com/v1")
        == "https://api.marketstack.com/v2"
    )
    assert (
        MarketstackClient.resolve_v2_base_url("https://api.marketstack.com/v2")
        == "https://api.marketstack.com/v2"
    )


def test_dividends_client_uses_v2_even_when_configured_v1():
    client = MarketstackClient(base_url="https://api.marketstack.com/v1")
    assert client._dividends_base_url() == "https://api.marketstack.com/v2"
