from app.clients.brapi.client import BrapiClient
from app.clients.brapi.stock_mapper import STOCK_DETAIL_MODULES, map_enriched_market_quote
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
    StockCatalogResponse,
)
from app.domain.fii.models import FiiCandlesResponse
from app.config import settings
from app.core.cache import TtlCache
from app.core.exceptions import UpstreamError
from app.domain.quotes.category_map import (
    BRAPI_LIST_TYPE,
    CATEGORY_SLUGS,
    FEATURED_STOCK_TICKERS,
    category_to_slug,
    infer_category,
    is_international_etf,
)
from app.domain.market_heatmap.presets import (
    DEFAULT_HEATMAP_LIMIT,
    MAX_HEATMAP_LIMIT,
    MIN_BR_STOCK_HEATMAP_VOLUME,
)
from app.providers.registry import AssetClass, DataProvider, provider_for


class QuoteService:
    """Cotações B3 via Brapi — ações, BDRs, ETFs BR e FIIs."""

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
        catalog_ttl = settings.quote_cache_ttl_seconds * 24
        self._catalog_cache: TtlCache[StockCatalogResponse] = TtlCache(catalog_ttl)
        self._catalog_total_cache: TtlCache[int] = TtlCache(catalog_ttl)
        self._featured_cache: TtlCache[MarketQuoteBatchResponse] = TtlCache(
            settings.quote_cache_ttl_seconds,
        )
        self._heatmap_cache: TtlCache[MarketQuoteBatchResponse] = TtlCache(
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
        if not filtered and len(q) >= 2:
            result = await self._search_catalog(q, limit=limit)
        self._list_cache.set(cache_key, result)
        return result

    async def _search_catalog(self, query: str, *, limit: int) -> MarketQuoteListResponse:
        lowered = query.lower()
        items: list[MarketQuote] = []
        seen: set[str] = set()

        for slug in ("acoes_br", "bdr", "etf"):
            catalog = await self.get_stock_catalog(slug)
            for entry in catalog.items:
                if entry.symbol in seen:
                    continue
                haystack = f"{entry.symbol} {entry.name}".lower()
                if not self._catalog_entry_matches(lowered, entry.symbol, entry.name):
                    continue
                seen.add(entry.symbol)
                items.append(
                    MarketQuote(
                        symbol=entry.symbol,
                        name=entry.name,
                        price=0,
                        change_percent=0,
                        category=entry.category,
                    )
                )
                if len(items) >= limit:
                    return MarketQuoteListResponse(items=items, count=len(items))

        return MarketQuoteListResponse(items=items, count=len(items))

    @staticmethod
    def _catalog_entry_matches(query: str, symbol: str, name: str) -> bool:
        haystack = f"{symbol} {name}".lower()
        if query in haystack:
            return True
        if len(query) >= 4 and query[:4].isalpha() and symbol.lower().startswith(query[:4]):
            return True
        return False

    async def get_stock_catalog(self, category_slug: str) -> StockCatalogResponse:
        cache_key = f"catalog:{category_slug}"
        cached = self._catalog_cache.get(cache_key)
        if cached:
            return cached

        source_slug = "etf" if category_slug == "etf_intl" else category_slug
        result = await self._client.load_stock_catalog(source_slug)
        if category_slug == "etf_intl":
            items = [item for item in result.items if is_international_etf(item.symbol)]
            result = StockCatalogResponse(
                quote_type=result.quote_type,
                items=items,
                count=len(items),
                total=len(items),
                sectors=sorted({item.sector for item in items if item.sector}),
            )
        elif category_slug == "etf":
            items = [item for item in result.items if not is_international_etf(item.symbol)]
            result = StockCatalogResponse(
                quote_type=result.quote_type,
                items=items,
                count=len(items),
                total=len(items),
                sectors=sorted({item.sector for item in items if item.sector}),
            )

        self._catalog_cache.set(cache_key, result)
        return result

    def get_cached_catalog_total(self, category_slug: str) -> int | None:
        cached = self._catalog_cache.get(f"catalog:{category_slug}")
        if cached:
            return cached.total or cached.count
        return None

    async def get_stock_catalog_total(self, category_slug: str) -> int:
        cached_total = self.get_cached_catalog_total(category_slug)
        if cached_total is not None:
            return cached_total

        count_key = f"total:{category_slug}"
        cached_count = self._catalog_total_cache.get(count_key)
        if cached_count is not None:
            return cached_count

        if category_slug in {"etf", "etf_intl"}:
            catalog = await self.get_stock_catalog(category_slug)
            total = catalog.total or catalog.count
            self._catalog_total_cache.set(count_key, total)
            return total

        total = await self._client.fetch_stock_list_total(category_slug)
        self._catalog_total_cache.set(count_key, total)
        return total

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

        cache_key = f"list:v2:{category_slug}:{limit}:{page}"
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
            if category_slug == "etf_intl":
                items = [
                    item
                    for item in raw_items
                    if infer_category(item.symbol, "stock") == AssetClass.ETF_BR
                    and is_international_etf(item.symbol)
                ]
            else:
                items = [
                    item
                    for item in raw_items
                    if infer_category(item.symbol, "stock") == AssetClass.ETF_BR
                    and not is_international_etf(item.symbol)
                ]
        else:
            items = raw_items

        for item in items:
            item.category = category_slug if category_slug == "etf_intl" else category_to_slug(asset_class)

        trimmed = items[:limit]
        enriched = await self._attach_brapi_sparklines(trimmed)
        result = MarketQuoteListResponse(items=enriched, count=len(enriched))
        self._list_cache.set(cache_key, result)
        return result

    async def _attach_brapi_sparklines(self, items: list[MarketQuote]) -> list[MarketQuote]:
        if not items:
            return items

        from app.clients.brapi.stock_mapper import sparkline_from_price_points

        symbols = [item.symbol for item in items]
        spark_by_symbol: dict[str, list[float]] = {}
        try:
            raw_items = await self._client.get_quotes_with_history(symbols, range_="3mo")
            for raw in raw_items:
                symbol = str(raw.get("symbol") or raw.get("stock") or "").upper().strip()
                if not symbol:
                    continue
                spark = sparkline_from_price_points(raw.get("historicalDataPrice") or [])
                if spark:
                    spark_by_symbol[symbol] = spark
        except UpstreamError:
            pass

        enriched: list[MarketQuote] = []
        for item in items:
            spark = spark_by_symbol.get(item.symbol, [])
            enriched.append(item.model_copy(update={"sparkline": spark}))
        return enriched

    async def _attach_screener_sparklines(self, result: StockScreenerResponse) -> StockScreenerResponse:
        from app.clients.brapi.stock_mapper import sparkline_from_price_points

        symbols = [item.symbol for item in result.items]
        if not symbols:
            return result

        spark_by_symbol: dict[str, list[float]] = {}
        try:
            raw_items = await self._client.get_quotes_with_history(symbols, range_="3mo")
            for raw in raw_items:
                symbol = str(raw.get("symbol") or raw.get("stock") or "").upper().strip()
                if not symbol:
                    continue
                spark = sparkline_from_price_points(raw.get("historicalDataPrice") or [])
                if spark:
                    spark_by_symbol[symbol] = spark
        except UpstreamError:
            pass

        items = [
            item.model_copy(
                update={
                    "sparkline": spark_by_symbol.get(item.symbol, [])
                }
            )
            for item in result.items
        ]
        return result.model_copy(update={"items": items})

    async def featured_stocks(self) -> MarketQuoteBatchResponse:
        cached = self._featured_cache.get("featured:v2")
        if cached:
            return cached

        try:
            raw_items = await self._client.get_quotes_with_modules(
                list(FEATURED_STOCK_TICKERS),
                modules=STOCK_DETAIL_MODULES,
            )
            items = [
                map_enriched_market_quote(item)
                for item in raw_items
                if item.get("symbol")
            ]
        except UpstreamError:
            items = await self._client.get_quotes(list(FEATURED_STOCK_TICKERS))

        by_symbol = {item.symbol: item for item in items}
        ordered = [by_symbol[ticker] for ticker in FEATURED_STOCK_TICKERS if ticker in by_symbol]
        ordered = await self._attach_brapi_sparklines(ordered)
        result = MarketQuoteBatchResponse(items=ordered, count=len(ordered))
        self._featured_cache.set("featured:v2", result)
        return result

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
        result = await self._attach_screener_sparklines(result)
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

    async def get_stock_heatmap(self, *, limit: int = DEFAULT_HEATMAP_LIMIT) -> MarketQuoteBatchResponse:
        """Top ações B3 por volume do pregão — mapa de calor (somente ações BR)."""
        safe_limit = max(1, min(limit, MAX_HEATMAP_LIMIT))
        cache_key = f"heatmap:{safe_limit}"
        cached = self._heatmap_cache.get(cache_key)
        if cached:
            return cached

        screener = await self.screener(
            quote_type="stock",
            sort_by="volume",
            sort_order="desc",
            limit=min(safe_limit * 2, MAX_HEATMAP_LIMIT * 2),
            page=1,
        )
        items: list[MarketQuote] = []
        for row in screener.items:
            if row.category != "acoes_br":
                continue
            if (row.volume or 0) < MIN_BR_STOCK_HEATMAP_VOLUME:
                continue
            items.append(
                MarketQuote(
                    symbol=row.symbol,
                    name=row.name,
                    price=row.price,
                    change_percent=row.change_percent,
                    category=row.category,
                    provider=row.provider,
                    volume=row.volume,
                    logo_url=row.logo_url,
                    dividend_yield_12m=row.dividend_yield_12m,
                    price_to_book=row.price_to_book,
                )
            )
            if len(items) >= safe_limit:
                break

        result = MarketQuoteBatchResponse(items=items, count=len(items), provider="brapi")
        self._heatmap_cache.set(cache_key, result)
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
