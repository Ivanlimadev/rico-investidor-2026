import asyncio

from app.clients.brapi.models import MarketQuoteBatchResponse
from app.domain.home.models import FeaturedFiisFeed, HomeFeedResponse, MarketCounts
from app.services.crypto_service import crypto_service
from app.services.global_market_service import global_market_service
from app.core.cache import TtlCache
from app.config import settings


class HomeService:
    def __init__(self) -> None:
        self._feed_cache: TtlCache[HomeFeedResponse] = TtlCache(settings.quote_cache_ttl_seconds)

    async def get_feed(self) -> HomeFeedResponse:
        cached = self._feed_cache.get("feed")
        if cached:
            return cached

        (
            featured_us_stocks,
            cripto_count,
            stocks_us_count,
            world_exchanges,
        ) = await asyncio.gather(
            global_market_service.list_featured_us(),
            crypto_service.count_coins(),
            global_market_service.count_us_stocks(),
            global_market_service.list_world_exchanges(),
            return_exceptions=True,
        )

        market_counts = MarketCounts()
        if not isinstance(cripto_count, Exception):
            market_counts.cripto = cripto_count
        if not isinstance(stocks_us_count, Exception):
            market_counts.stocks_us = stocks_us_count
        if not isinstance(world_exchanges, Exception):
            market_counts.world_exchanges = world_exchanges.total_exchanges

        us_stocks = featured_us_stocks if not isinstance(featured_us_stocks, Exception) else None

        result = HomeFeedResponse(
            featured_us_stocks=us_stocks,
            featured_stocks=MarketQuoteBatchResponse(items=[], count=0),
            featured_fiis=FeaturedFiisFeed(),
            market_counts=market_counts,
            macro=None,
        )
        self._feed_cache.set("feed", result)
        return result


home_service = HomeService()
