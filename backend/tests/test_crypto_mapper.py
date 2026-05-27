from app.clients.binance.crypto_mapper import (
    map_klines,
    map_ticker_24hr,
    map_ticker_24hr_batch,
    map_usdt_catalog,
    normalize_crypto_symbol,
    pair_to_base,
    to_usdt_pair,
)


def test_normalize_crypto_symbol():
    assert normalize_crypto_symbol(" btc ") == "BTC"
    assert normalize_crypto_symbol("BTCUSDT") == "BTC"
    assert to_usdt_pair("eth") == "ETHUSDT"
    assert pair_to_base("SOLUSDT") == "SOL"


def test_map_ticker_24hr_batch():
    payload = {
        "symbol": "BTCUSDT",
        "priceChange": "-120.00000000",
        "priceChangePercent": "-1.359",
        "lastPrice": "97234.56000000",
        "highPrice": "98500.00000000",
        "lowPrice": "96800.00000000",
        "quoteVolume": "1234567890.00000000",
        "closeTime": 1779921095008,
    }

    result = map_ticker_24hr_batch(payload)

    assert result.count == 1
    assert result.provider == "binance"
    assert result.items[0].symbol == "BTC"
    assert result.items[0].currency == "USD"
    assert result.items[0].name == "Bitcoin"
    assert result.items[0].price == 97234.56
    assert result.items[0].change_percent == -1.359


def test_map_usdt_catalog():
    result = map_usdt_catalog(["BTCUSDT", "ETHUSDT", "SOLUSDT"])

    assert result.count == 3
    assert result.coins == ["BTC", "ETH", "SOL"]


def test_map_klines():
    payload = [
        [1779753600000, "97000.00", "97500.00", "96500.00", "97200.00", "152.98"],
        [1779840000000, "97200.00", "97300.00", "96800.00", "97234.56", "91.12"],
    ]

    result = map_klines(payload, symbol="BTC", limit=252)

    assert result.symbol == "BTC"
    assert result.currency == "USD"
    assert result.provider == "binance"
    assert result.count == 2
    assert result.history[1].value == 97234.56
