import asyncio

from app.clients.brapi.models import MarketQuoteBatchResponse
from app.domain.home.models import HomeFeedResponse, MarketCounts
from app.services.crypto_service import crypto_service
from app.services.currency_service import currency_service
from app.services.fii_service import fii_service
from app.services.global_market_service import global_market_service
from app.services.indices_service import indices_service
from app.services.quote_service import quote_service
from app.services.treasury_service import treasury_service
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
            featured_stocks,
            featured_fiis,
            fii_count,
            acoes_total,
            bdr_total,
            moeda_count,
            tesouro_count,
            indices_count,
            cripto_count,
            stocks_us_count,
            world_exchanges,
        ) = await asyncio.gather(
            global_market_service.list_featured_us(),
            quote_service.featured_stocks(),
            fii_service.featured_fiis(),
            fii_service.count_fiis(),
            quote_service.get_stock_catalog_total("acoes_br"),
            quote_service.get_stock_catalog_total("bdr"),
            currency_service.count_brl_pairs(),
            treasury_service.count_bonds(),
            indices_service.count_indices(),
            crypto_service.count_coins(),
            global_market_service.count_us_stocks(),
            global_market_service.list_world_exchanges(),
            return_exceptions=True,
        )

        market_counts = MarketCounts()
        if not isinstance(fii_count, Exception):
            market_counts.fiis = fii_count
        if not isinstance(acoes_total, Exception):
            market_counts.acoes_br = acoes_total
        if not isinstance(bdr_total, Exception):
            market_counts.bdr = bdr_total
        if not isinstance(moeda_count, Exception):
            market_counts.moeda = moeda_count
        if not isinstance(tesouro_count, Exception):
            market_counts.tesouro = tesouro_count
        if not isinstance(indices_count, Exception):
            market_counts.indices = indices_count
        if not isinstance(cripto_count, Exception):
            market_counts.cripto = cripto_count
        if not isinstance(stocks_us_count, Exception):
            market_counts.stocks_us = stocks_us_count
        if not isinstance(world_exchanges, Exception):
            market_counts.world_exchanges = world_exchanges.total_exchanges

        market_counts.etf = quote_service.get_cached_catalog_total("etf")
        market_counts.etf_intl = quote_service.get_cached_catalog_total("etf_intl")

        if isinstance(featured_stocks, Exception):
            featured_stocks = MarketQuoteBatchResponse(items=[], count=0)
        if isinstance(featured_fiis, Exception):
            raise featured_fiis

        us_stocks = featured_us_stocks if not isinstance(featured_us_stocks, Exception) else None

        result = HomeFeedResponse(
            featured_us_stocks=us_stocks,
            featured_stocks=featured_stocks,
            featured_fiis=featured_fiis,
            market_counts=market_counts,
            macro=None,
        )
        self._feed_cache.set("feed", result)
        asyncio.create_task(self._warm_catalog_totals())
        return result

    async def _warm_catalog_totals(self) -> None:
        for slug in ("etf", "etf_intl"):
            try:
                await quote_service.get_stock_catalog_total(slug)
            except Exception:
                continue


home_service = HomeService()
