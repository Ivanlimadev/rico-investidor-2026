from app.clients.brapi.client import BrapiClient
from app.clients.brapi.models import (
    MarketQuote,
    MarketQuoteBatchResponse,
    MarketQuoteListResponse,
    StockDividendsResponse,
    StockQuoteDetailResponse,
    StockScreenerResponse,
    StockFinancialsResponse,
    StockFundamentalHistoryResponse,
    StockCompareResponse,
    StockPerformanceResponse,
)
from app.clients.bolsai.models import FiiCandlesResponse
from app.config import settings
from app.core.cache import TtlCache
from app.core.exceptions import UpstreamError
from app.domain.quotes.category_map import (
    BRAPI_LIST_TYPE,
    CATEGORY_SLUGS,
    FEATURED_STOCK_TICKERS,
    category_to_slug,
    infer_category,
)
from app.providers.registry import AssetClass, DataProvider, provider_for


class QuoteService:
    """Cotações B3 via Brapi — ações, BDRs e ETFs BR (FIIs continuam na Bolsai)."""

    def __init__(self, client: BrapiClient | None = None) -> None:
        self._client = client or BrapiClient()
        self._quote_cache: TtlCache[MarketQuote] = TtlCache(settings.quote_cache_ttl_seconds)
        self._list_cache: TtlCache[MarketQuoteListResponse] = TtlCache(
            settings.quote_cache_ttl_seconds
        )
        self._detail_cache: TtlCache[StockQuoteDetailResponse] = TtlCache(
            settings.quote_cache_ttl_seconds
        )
        self._candles_cache: TtlCache[FiiCandlesResponse] = TtlCache(
            settings.quote_cache_ttl_seconds
        )
        self._screener_cache: TtlCache[StockScreenerResponse] = TtlCache(
            settings.quote_cache_ttl_seconds
        )
        self._financials_cache: TtlCache[StockFinancialsResponse] = TtlCache(
            settings.quote_cache_ttl_seconds * 4,
        )
        self._fundamental_history_cache: TtlCache[StockFundamentalHistoryResponse] = TtlCache(
            settings.quote_cache_ttl_seconds * 4,
        )
        self._compare_cache: TtlCache[StockCompareResponse] = TtlCache(
            settings.quote_cache_ttl_seconds,
        )
        self._performance_cache: TtlCache[StockPerformanceResponse] = TtlCache(
            settings.quote_cache_ttl_seconds,
        )

    @staticmethod
    def provider() -> DataProvider:
        return provider_for(AssetClass.STOCK_BR)

    async def get_quote(self, ticker: str) -> MarketQuote:
        normalized = ticker.upper().strip()
        cached = self._quote_cache.get(normalized)
        if cached:
            return cached

        items = await self._client.get_quotes([normalized])
        if not items:
            raise UpstreamError(f"Cotação não encontrada: {normalized}", status_code=404)

        quote = items[0]
        self._quote_cache.set(normalized, quote)
        return quote

    async def get_quotes_batch(self, tickers: list[str]) -> MarketQuoteBatchResponse:
        normalized = [t.upper().strip() for t in tickers if t.strip()]
        if not normalized:
            return MarketQuoteBatchResponse(items=[], count=0)

        cached_items: list[MarketQuote] = []
        missing: list[str] = []
        for ticker in normalized:
            cached = self._quote_cache.get(ticker)
            if cached:
                cached_items.append(cached)
            else:
                missing.append(ticker)

        fetched: list[MarketQuote] = []
        for offset in range(0, len(missing), BrapiClient.MAX_BATCH):
            batch = missing[offset : offset + BrapiClient.MAX_BATCH]
            batch_items = await self._client.get_quotes(batch)
            for item in batch_items:
                self._quote_cache.set(item.symbol, item)
            fetched.extend(batch_items)

        by_symbol = {item.symbol: item for item in cached_items + fetched}
        ordered = [by_symbol[t] for t in normalized if t in by_symbol]
        return MarketQuoteBatchResponse(items=ordered, count=len(ordered))

    async def search(self, query: str, *, limit: int = 20) -> MarketQuoteListResponse:
        q = query.strip()
        cache_key = f"search:{q.lower()}:{limit}"
        cached = self._list_cache.get(cache_key)
        if cached:
            return cached

        raw_items = await self._client.list_quotes(search=q, limit=min(limit * 2, 40))
        filtered = [
            item
            for item in raw_items
            if infer_category(item.symbol, None) != AssetClass.FII
        ][:limit]

        result = MarketQuoteListResponse(items=filtered, count=len(filtered))
        self._list_cache.set(cache_key, result)
        return result

    async def list_by_category(
        self,
        category_slug: str,
        *,
        limit: int = 30,
        page: int = 1,
    ) -> MarketQuoteListResponse:
        asset_class = CATEGORY_SLUGS.get(category_slug)
        if asset_class is None:
            raise ValueError(f"Categoria inválida: {category_slug}")

        cache_key = f"list:{category_slug}:{limit}:{page}"
        cached = self._list_cache.get(cache_key)
        if cached:
            return cached

        quote_type = BRAPI_LIST_TYPE.get(asset_class)
        raw_items = await self._client.list_quotes(
            quote_type=quote_type,
            limit=limit,
            page=page,
        )

        if asset_class == AssetClass.STOCK_BR:
            items = [
                item
                for item in raw_items
                if infer_category(item.symbol, "stock") == AssetClass.STOCK_BR
            ]
        elif asset_class == AssetClass.ETF_BR:
            items = [
                item
                for item in raw_items
                if infer_category(item.symbol, "stock") == AssetClass.ETF_BR
            ]
        else:
            items = raw_items

        for item in items:
            item.category = category_to_slug(asset_class)

        result = MarketQuoteListResponse(items=items[:limit], count=min(len(items), limit))
        self._list_cache.set(cache_key, result)
        return result

    async def featured_stocks(self) -> MarketQuoteBatchResponse:
        return await self.get_quotes_batch(list(FEATURED_STOCK_TICKERS))

    async def get_stock_detail(
        self,
        ticker: str,
        *,
        candle_limit: int = 252,
        dividend_limit: int = 120,
    ) -> StockQuoteDetailResponse:
        normalized = ticker.upper().strip()
        cache_key = f"detail:{normalized}:{candle_limit}:{dividend_limit}"
        cached = self._detail_cache.get(cache_key)
        if cached:
            return cached

        result = await self._client.get_stock_detail(
            normalized,
            candle_limit=candle_limit,
            dividend_limit=dividend_limit,
        )
        self._detail_cache.set(cache_key, result)
        self._quote_cache.set(normalized, result.quote)
        return result

    async def get_stock_candles(
        self,
        ticker: str,
        *,
        limit: int = 252,
        range_: str | None = None,
        interval: str = "1d",
    ) -> FiiCandlesResponse:
        normalized = ticker.upper().strip()
        cache_key = f"candles:{normalized}:{range_ or ''}:{interval}:{limit}"
        cached = self._candles_cache.get(cache_key)
        if cached:
            return cached

        result = await self._client.get_stock_candles(
            normalized,
            limit=limit,
            range_=range_,
            interval=interval,
        )
        self._candles_cache.set(cache_key, result)
        return result

    async def get_stock_dividends(self, ticker: str, *, limit: int = 24) -> StockDividendsResponse:
        detail = await self.get_stock_detail(ticker, candle_limit=30, dividend_limit=limit)
        return detail.dividends

    async def screener(
        self,
        *,
        sector: str | None = None,
        quote_type: str = "stock",
        search: str | None = None,
        sort_by: str = "volume",
        sort_order: str = "desc",
        limit: int = 50,
        page: int = 1,
        min_dividend_yield: float | None = None,
        max_dividend_yield: float | None = None,
        min_price_earnings: float | None = None,
        max_price_earnings: float | None = None,
        min_return_on_equity: float | None = None,
        max_return_on_equity: float | None = None,
        min_price_to_book: float | None = None,
        max_price_to_book: float | None = None,
    ) -> StockScreenerResponse:
        cache_key = (
            f"screener:{quote_type}:{sort_by}:{sort_order}:{limit}:{page}:"
            f"{sector or ''}:{search or ''}:"
            f"{min_dividend_yield}:{max_dividend_yield}:"
            f"{min_price_earnings}:{max_price_earnings}:"
            f"{min_return_on_equity}:{max_return_on_equity}:"
            f"{min_price_to_book}:{max_price_to_book}"
        )
        cached = self._screener_cache.get(cache_key)
        if cached:
            return cached

        result = await self._client.screener_quotes(
            sector=sector,
            quote_type=quote_type,
            search=search,
            sort_by=sort_by,
            sort_order=sort_order,
            limit=limit,
            page=page,
            min_dividend_yield=min_dividend_yield,
            max_dividend_yield=max_dividend_yield,
            min_price_earnings=min_price_earnings,
            max_price_earnings=max_price_earnings,
            min_return_on_equity=min_return_on_equity,
            max_return_on_equity=max_return_on_equity,
            min_price_to_book=min_price_to_book,
            max_price_to_book=max_price_to_book,
        )
        self._screener_cache.set(cache_key, result)
        return result

    async def get_stock_fundamental_history(
        self,
        ticker: str,
        *,
        limit: int = 12,
    ) -> StockFundamentalHistoryResponse:
        normalized = ticker.upper().strip()
        cache_key = f"fundamental_history:{normalized}:{limit}"
        cached = self._fundamental_history_cache.get(cache_key)
        if cached:
            return cached

        result = await self._client.get_stock_fundamental_history(normalized, limit=limit)
        self._fundamental_history_cache.set(cache_key, result)
        return result

    async def get_stock_financials(
        self,
        ticker: str,
        *,
        limit: int = 8,
        period: str = "quarterly",
    ) -> StockFinancialsResponse:
        normalized = ticker.upper().strip()
        cache_key = f"financials:{normalized}:{period}:{limit}"
        cached = self._financials_cache.get(cache_key)
        if cached:
            return cached

        result = await self._client.get_stock_financials(normalized, limit=limit, period=period)
        self._financials_cache.set(cache_key, result)
        return result

    async def get_stock_performance(
        self,
        ticker: str,
        *,
        limit: int = 252,
        range_: str | None = None,
        benchmark: str = "^BVSP",
    ) -> StockPerformanceResponse:
        normalized = ticker.upper().strip()
        normalized_benchmark = benchmark.upper().strip()
        cache_key = f"performance:{normalized}:{normalized_benchmark}:{range_ or ''}:{limit}"
        cached = self._performance_cache.get(cache_key)
        if cached:
            return cached

        result = await self._client.get_stock_performance(
            normalized,
            limit=limit,
            range_=range_,
            benchmark=normalized_benchmark,
        )
        self._performance_cache.set(cache_key, result)
        return result

    async def compare_stocks(self, tickers: list[str]) -> StockCompareResponse:
        normalized = [t.upper().strip() for t in tickers if t.strip()]
        cache_key = "compare:" + ",".join(sorted(normalized))
        cached = self._compare_cache.get(cache_key)
        if cached:
            return cached

        result = await self._client.get_stock_compare(normalized)
        self._compare_cache.set(cache_key, result)
        return result


quote_service = QuoteService()
