from app.clients.brapi.models import (
    MarketQuote,
    StockDividendsResponse,
    StockFundamentals,
    StockMarketStats,
    StockProfile,
)
from app.services.quote_service import QuoteService, _DetailFastBundle, _DetailSlowBundle


def test_detail_fast_and_slow_caches_use_different_ttl_buckets():
    service = QuoteService(client=None)  # type: ignore[arg-type]
    assert service._detail_fast_cache._ttl == service._quote_cache._ttl
    assert service._detail_slow_cache._ttl > service._detail_fast_cache._ttl


def test_merge_detail_bundles_applies_slow_enrichment_to_fast_quote():
    service = QuoteService(client=None)  # type: ignore[arg-type]
    fast = _DetailFastBundle(
        quote=MarketQuote(
            symbol="PETR4",
            name="Petrobras",
            price=30.0,
            change_percent=1.0,
            category="acoes_br",
        ),
        market_stats=StockMarketStats(),
        profile=StockProfile(),
        fundamentals=StockFundamentals(),
        candles=(),
    )
    slow = _DetailSlowBundle(
        dividends=StockDividendsResponse(ticker="PETR4", count=0, provider="bolsai"),
        fundamentals=StockFundamentals(price_earnings=5.0),
        market_stats=StockMarketStats(volume=1_000_000),
        profile=StockProfile(sector="Energy"),
        quote_name="Petrobras PN",
        provider="hybrid",
    )

    merged = service._merge_detail_bundles(fast, slow)

    assert merged.provider == "hybrid"
    assert merged.quote.name == "Petrobras PN"
    assert merged.fundamentals.price_earnings == 5.0
    assert merged.profile.sector == "Energy"
    assert merged.market_stats.volume == 1_000_000
