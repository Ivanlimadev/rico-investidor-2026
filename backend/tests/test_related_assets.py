from app.domain.related_assets.resolver import normalize_ticker, resolve_peer_candidates


def test_itub4_peers_are_banks():
    label, peers = resolve_peer_candidates("ITUB4", market="acoes_br", limit=6)
    symbols = [s for s, _ in peers]

    assert "Bancos" in label or "bancos" in label.lower()
    assert "ITUB4" not in symbols
    assert "BBDC4" in symbols
    assert "SANB11" in symbols


def test_nvda_peers_include_semiconductors():
    label, peers = resolve_peer_candidates("NVDA", market="stocks", limit=6)
    symbols = [s for s, _ in peers]

    assert "NVDA" not in symbols
    assert "AMD" in symbols
    assert any("chip" in label.lower() or "semi" in label.lower() or "tech" in label.lower() for _ in [label])


def test_eth_crypto_peers():
    _, peers = resolve_peer_candidates("ETH", market="cripto", limit=6)
    symbols = [s for s, _ in peers]

    assert "ETH" not in symbols
    assert "BTC" in symbols
    assert "SOL" in symbols


def test_normalize_ticker_strips_sa_suffix():
    assert normalize_ticker("petr4.sa") == "PETR4"
