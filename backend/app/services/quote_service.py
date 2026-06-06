from dataclasses import dataclass

from app.clients.brapi.client import BrapiClient
from app.clients.brapi.stock_mapper import STOCK_DETAIL_MODULES, map_enriched_market_quote
from app.clients.brapi.models import (
    MarketQuote,
    MarketQuoteBatchResponse,
    MarketQuoteListResponse,
    StockDividendsResponse,
    StockFundamentals,
    StockMarketStats,
    StockProfile,
    StockQuoteDetailResponse,
    StockScreenerResponse,
    StockFinancialsResponse,
    StockFundamentalHistoryResponse,
    StockCompareItem,
    StockCompareResponse,
    StockPerformanceResponse,
    StockCatalogResponse,
)
from app.domain.fii.models import FiiCandleBar, FiiCandlesResponse
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
from app.clients.bolsai.fundamentals_mapper import (
    fundamentals_updates_from_bolsai,
    merge_bolsai_market_stats,
)
from app.clients.bolsai.history_mapper import map_bolsai_fundamental_history, map_bolsai_stock_candles
from app.domain.quotes.compare_enrichment import merge_bolsai_fundamentals_for_ticker
import asyncio

from app.domain.quotes.hybrid_br_sources import (
    hybrid_provider_label,
    prefer_bolsai_candles,
    prefer_bolsai_screener,
)
from app.providers.registry import AssetClass, DataProvider, provider_for
from app.services.br_proventos_service import br_proventos_service


@dataclass(frozen=True)
class _DetailFastBundle:
    quote: MarketQuote
    market_stats: StockMarketStats
    profile: StockProfile
    fundamentals: StockFundamentals
    candles: tuple[FiiCandleBar, ...]


@dataclass(frozen=True)
class _DetailSlowBundle:
    dividends: StockDividendsResponse
    fundamentals: StockFundamentals
    market_stats: StockMarketStats
    profile: StockProfile
    quote_name: str | None
    provider: str
    bolsai_quote: dict | None = None
    bolsai_fundamentals: dict | None = None


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
        self._detail_fast_cache: TtlCache[_DetailFastBundle] = TtlCache(
            settings.quote_cache_ttl_seconds,
        )
        self._detail_slow_cache: TtlCache[_DetailSlowBundle] = TtlCache(
            settings.bolsai_ticker_cache_ttl_seconds,
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

        quote = await br_proventos_service.reconcile_market_quote(items[0])
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
        ordered = await br_proventos_service.reconcile_market_quotes_batch(ordered)
        for item in ordered:
            self._quote_cache.set(item.symbol, item)
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
        enriched = await br_proventos_service.reconcile_market_quotes_batch(enriched)
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
        cache_tag = "featured:v3:bolsai" if br_proventos_service.uses_bolsai else "featured:v3"
        cached = self._featured_cache.get(cache_tag)
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
        ordered = await br_proventos_service.reconcile_market_quotes_batch(ordered)
        result = MarketQuoteBatchResponse(items=ordered, count=len(ordered))
        self._featured_cache.set(cache_tag, result)
        return result

    async def get_stock_detail(
        self,
        ticker: str,
        *,
        candle_limit: int = 252,
        dividend_limit: int = 120,
    ) -> StockQuoteDetailResponse:
        normalized = ticker.upper().strip()
        if br_proventos_service.uses_bolsai:
            fast = await self._load_detail_fast_bundle(
                normalized,
                candle_limit=candle_limit,
                dividend_limit=dividend_limit,
            )
            slow = await self._load_detail_slow_bundle(
                normalized,
                dividend_limit=dividend_limit,
                fundamentals_base=fast.fundamentals,
                market_stats_base=fast.market_stats,
                profile_base=fast.profile,
            )
            result = self._merge_detail_bundles(fast, slow)
            result = await self._apply_detail_candle_enrichment(
                normalized,
                result,
                candle_limit=candle_limit,
            )
            self._quote_cache.set(normalized, result.quote)
            return result

        div_source = "brapi"
        cache_key = f"detail:{normalized}:{candle_limit}:{dividend_limit}:{div_source}"
        cached = self._detail_cache.get(cache_key)
        if cached:
            return cached

        result = await self._client.get_stock_detail(
            normalized,
            candle_limit=candle_limit,
            dividend_limit=dividend_limit,
            include_dividends=True,
        )
        dividends = await br_proventos_service.get_stock_dividends(
            normalized,
            limit=dividend_limit,
        )
        dividends = br_proventos_service.enrich_dividends_with_summary(
            dividends,
            price=result.quote.price,
        )
        fundamentals = br_proventos_service.merge_dividend_yield_into_fundamentals(
            result.fundamentals,
            dividends,
        )
        provider = hybrid_provider_label(
            bolsai_used=False,
            brapi_used=True,
        )
        result = result.model_copy(
            update={
                "dividends": dividends,
                "fundamentals": fundamentals,
                "provider": provider,
            }
        )
        result = await self._apply_detail_candle_enrichment(
            normalized,
            result,
            candle_limit=candle_limit,
        )
        self._detail_cache.set(cache_key, result)
        self._quote_cache.set(normalized, result.quote)
        return result

    async def _apply_detail_candle_enrichment(
        self,
        ticker: str,
        result: StockQuoteDetailResponse,
        *,
        candle_limit: int,
    ) -> StockQuoteDetailResponse:
        from app.domain.global_markets.candle_stats import enrich_market_stats_from_fii_candles

        candles = list(result.candles)
        if br_proventos_service.uses_bolsai and prefer_bolsai_candles(
            range_=None,
            limit=candle_limit,
        ):
            hybrid = await self._get_stock_candles_hybrid(
                ticker,
                limit=candle_limit,
                range_=None,
                interval="1d",
            )
            if hybrid.candles:
                candles = hybrid.candles

        if not candles:
            return result

        from app.domain.quotes.stock_returns import compute_stock_returns

        returns = compute_stock_returns(
            candles,
            current_price=result.quote.price,
            payments=result.dividends.payments,
        )

        return result.model_copy(
            update={
                "candles": candles,
                "market_stats": enrich_market_stats_from_fii_candles(
                    result.market_stats,
                    candles,
                ),
                "returns": returns,
            }
        )

    async def _load_detail_fast_bundle(
        self,
        ticker: str,
        *,
        candle_limit: int,
        dividend_limit: int,
    ) -> _DetailFastBundle:
        cache_key = f"detail_fast:{ticker}:{candle_limit}:{dividend_limit}"
        cached = self._detail_fast_cache.get(cache_key)
        if cached is not None:
            return cached

        result = await self._client.get_stock_detail(
            ticker,
            candle_limit=candle_limit,
            dividend_limit=dividend_limit,
            include_dividends=False,
        )
        bundle = _DetailFastBundle(
            quote=result.quote,
            market_stats=result.market_stats,
            profile=result.profile,
            fundamentals=result.fundamentals,
            candles=tuple(result.candles),
        )
        self._detail_fast_cache.set(cache_key, bundle)
        return bundle

    async def _load_detail_slow_bundle(
        self,
        ticker: str,
        *,
        dividend_limit: int,
        fundamentals_base: StockFundamentals,
        market_stats_base: StockMarketStats,
        profile_base: StockProfile,
    ) -> _DetailSlowBundle:
        cache_key = f"detail_slow:{ticker}:{dividend_limit}:bolsai"
        cached = self._detail_slow_cache.get(cache_key)
        if cached is not None:
            return cached

        dividends = await br_proventos_service.get_stock_dividends(ticker, limit=dividend_limit)
        fundamentals = fundamentals_base
        market_stats = market_stats_base
        profile = profile_base
        quote_name: str | None = None

        fund_raw, quote_raw, company_raw = await asyncio.gather(
            br_proventos_service.get_fundamentals_cached(ticker),
            br_proventos_service._bolsai.get_stock_quote(ticker),
            br_proventos_service.get_company_cached(ticker),
            return_exceptions=True,
        )
        fund_payload = fund_raw if isinstance(fund_raw, dict) else None
        quote_payload = quote_raw if isinstance(quote_raw, dict) else None
        company_payload = company_raw if isinstance(company_raw, dict) else None
        if fund_payload:
            from app.clients.bolsai.fundamentals_mapper import merge_bolsai_fundamentals

            fundamentals = merge_bolsai_fundamentals(fundamentals, fund_payload)
        market_stats = merge_bolsai_market_stats(
            market_stats,
            fundamentals=fund_payload,
            quote=quote_payload,
        )
        if company_payload:
            from app.clients.bolsai.companies_mapper import (
                company_display_name,
                merge_company_into_profile,
            )

            quote_name = company_display_name(company_payload)
            profile = merge_company_into_profile(profile, company_payload)

        provider = hybrid_provider_label(bolsai_used=True, brapi_used=True)
        bundle = _DetailSlowBundle(
            dividends=dividends,
            fundamentals=fundamentals,
            market_stats=market_stats,
            profile=profile,
            quote_name=quote_name,
            provider=provider,
            bolsai_quote=quote_payload,
            bolsai_fundamentals=fund_payload,
        )
        self._detail_slow_cache.set(cache_key, bundle)
        return bundle

    def _merge_detail_bundles(
        self,
        fast: _DetailFastBundle,
        slow: _DetailSlowBundle,
    ) -> StockQuoteDetailResponse:
        from app.clients.bolsai.fundamentals_mapper import bolsai_quote_updates

        quote = fast.quote
        if slow.quote_name:
            quote = quote.model_copy(update={"name": slow.quote_name})

        quote_patch = bolsai_quote_updates(
            slow.bolsai_quote,
            fundamentals=slow.bolsai_fundamentals,
        )
        if quote_patch:
            quote = quote.model_copy(update=quote_patch)

        dividends = br_proventos_service.enrich_dividends_with_summary(
            slow.dividends,
            price=quote.price,
        )
        fundamentals = br_proventos_service.merge_dividend_yield_into_fundamentals(
            slow.fundamentals,
            dividends,
        )
        return StockQuoteDetailResponse(
            quote=quote,
            market_stats=slow.market_stats,
            profile=slow.profile,
            fundamentals=fundamentals,
            candles=list(fast.candles),
            dividends=dividends,
            provider=slow.provider,
        )

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

        result = await self._get_stock_candles_hybrid(
            normalized,
            limit=limit,
            range_=range_,
            interval=interval,
        )
        self._candles_cache.set(cache_key, result)
        return result

    async def get_stock_dividends(self, ticker: str, *, limit: int = 24) -> StockDividendsResponse:
        normalized = ticker.upper().strip()
        return await br_proventos_service.get_stock_dividends(normalized, limit=limit)

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
        bolsai_tag = ":bolsai" if br_proventos_service.uses_bolsai else ""
        cache_key = (
            f"screener:{quote_type}:{sort_by}:{sort_order}:{limit}:{page}:"
            f"{sector or ''}:{search or ''}:"
            f"{min_dividend_yield}:{max_dividend_yield}:"
            f"{min_price_earnings}:{max_price_earnings}:"
            f"{min_return_on_equity}:{max_return_on_equity}:"
            f"{min_price_to_book}:{max_price_to_book}{bolsai_tag}"
        )
        cached = self._screener_cache.get(cache_key)
        if cached:
            return cached

        use_bolsai = (
            br_proventos_service.uses_bolsai
            and prefer_bolsai_screener(
                quote_type=quote_type,
                sort_by=sort_by,
                sector=sector,
                min_dividend_yield=min_dividend_yield,
                max_dividend_yield=max_dividend_yield,
                min_price_earnings=min_price_earnings,
                max_price_earnings=max_price_earnings,
                min_return_on_equity=min_return_on_equity,
                max_return_on_equity=max_return_on_equity,
                min_price_to_book=min_price_to_book,
                max_price_to_book=max_price_to_book,
            )
        )
        if use_bolsai:
            result = await self._get_screener_bolsai_hybrid(
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
        else:
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
            result = await self._safe_enrich_screener_with_bolsai_dy(result)
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

        result = await self._get_fundamental_history_hybrid(normalized, limit=limit)
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
        bolsai_tag = ":bolsai" if br_proventos_service.uses_bolsai else ""
        cache_key = f"financials:{normalized}:{period}:{limit}{bolsai_tag}"
        cached = self._financials_cache.get(cache_key)
        if cached:
            return cached

        result = await self._get_financials_hybrid(normalized, limit=limit, period=period)
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

        try:
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
            if items:
                self._heatmap_cache.set(cache_key, result)
            return result
        except Exception:
            return MarketQuoteBatchResponse(items=[], count=0, provider="brapi")

    async def _safe_attach_bolsai_dividend_yields(
        self,
        items: list[MarketQuote],
    ) -> list[MarketQuote]:
        try:
            return await self._attach_bolsai_dividend_yields(items)
        except Exception:
            return items

    async def _attach_bolsai_dividend_yields(
        self,
        items: list[MarketQuote],
    ) -> list[MarketQuote]:
        return await br_proventos_service.reconcile_market_quotes_batch(items)

    async def _safe_enrich_screener_with_bolsai_dy(
        self,
        result: StockScreenerResponse,
    ) -> StockScreenerResponse:
        try:
            return await self._enrich_screener_with_bolsai_dy(result)
        except Exception:
            return result

    async def _enrich_screener_with_bolsai_dy(
        self,
        result: StockScreenerResponse,
    ) -> StockScreenerResponse:
        if not br_proventos_service.uses_bolsai or not result.items:
            return result
        page_symbols = [row.symbol for row in result.items]
        fund_map = await br_proventos_service.fetch_fundamentals_batch(
            page_symbols,
            max_concurrency=settings.bolsai_dy_enrich_concurrency,
            max_symbols=min(len(page_symbols), settings.bolsai_dy_list_max_symbols),
        )
        if not fund_map:
            return result
        items = []
        for row in result.items:
            payload = fund_map.get(row.symbol)
            if not payload:
                items.append(row)
                continue
            mapped = fundamentals_updates_from_bolsai(payload)
            updates = {
                key: mapped[key]
                for key in (
                    "dividend_yield_12m",
                    "price_earnings",
                    "return_on_equity",
                    "price_to_book",
                )
                if key in mapped
            }
            items.append(row.model_copy(update=updates) if updates else row)
        return result.model_copy(update={"items": items})

    async def compare_stocks(self, tickers: list[str]) -> StockCompareResponse:
        normalized = [t.upper().strip() for t in tickers if t.strip()]
        bolsai_tag = ":bolsai" if br_proventos_service.uses_bolsai else ""
        cache_key = "compare:" + ",".join(sorted(normalized)) + bolsai_tag
        cached = self._compare_cache.get(cache_key)
        if cached:
            return cached

        result = await self._client.get_stock_compare(normalized)
        enriched = await asyncio.gather(
            *[self._enrich_br_compare_item(item) for item in result.items],
            return_exceptions=True,
        )
        items: list[StockCompareItem] = []
        for index, row in enumerate(enriched):
            if isinstance(row, Exception):
                items.append(result.items[index])
            else:
                items.append(row)
        result = result.model_copy(update={"items": items})
        self._compare_cache.set(cache_key, result)
        return result

    async def _enrich_br_compare_item(self, item: StockCompareItem) -> StockCompareItem:
        ticker = item.quote.symbol
        price = item.quote.price

        dividends_task = br_proventos_service.get_stock_dividends(ticker, limit=80)
        candle_limit = 1260 if br_proventos_service.uses_bolsai else 280
        candles_task = self.get_stock_candles(
            ticker,
            limit=candle_limit,
            range_=None if br_proventos_service.uses_bolsai else "1y",
        )

        dividends_raw, candles_raw = await asyncio.gather(
            dividends_task,
            candles_task,
            return_exceptions=True,
        )

        fundamentals = item.fundamentals
        if br_proventos_service.uses_bolsai:
            from app.domain.quotes.compare_enrichment import merge_bolsai_fundamentals_for_ticker

            fundamentals = await merge_bolsai_fundamentals_for_ticker(
                fundamentals,
                ticker=ticker,
                bolsai=br_proventos_service._bolsai,
            )

        dividends_snapshot = item.dividends
        if isinstance(dividends_raw, StockDividendsResponse):
            div_enriched = br_proventos_service.enrich_dividends_with_summary(
                dividends_raw,
                price=price,
            )
            from app.domain.quotes.compare_enrichment import dividends_snapshot_from_stock

            dividends_snapshot = dividends_snapshot_from_stock(div_enriched)
            from app.domain.dividends.br_dividend_analytics import resolve_display_dividend_yield

            dy = resolve_display_dividend_yield(
                dividend_yield_display=dividends_snapshot.dividend_yield_display,
                dividend_yield_ttm=dividends_snapshot.dividend_yield_ttm,
            )
            if dy is not None:
                fundamentals = fundamentals.model_copy(update={"dividend_yield_12m": dy})

        from app.domain.quotes.compare_enrichment import compare_return_periods_from_candles

        candles = candles_raw.candles if hasattr(candles_raw, "candles") else []
        payments = (
            dividends_raw.payments
            if isinstance(dividends_raw, StockDividendsResponse)
            else []
        )
        returns = compare_return_periods_from_candles(
            candles,
            current_price=price,
            payments=payments,
        )

        return item.model_copy(
            update={
                "fundamentals": fundamentals,
                "dividends": dividends_snapshot,
                "returns": returns,
                "provider": hybrid_provider_label(
                    bolsai_used=br_proventos_service.uses_bolsai,
                    brapi_used=True,
                ),
            }
        )

    async def _get_stock_candles_hybrid(
        self,
        ticker: str,
        *,
        limit: int,
        range_: str | None,
        interval: str,
    ) -> FiiCandlesResponse:
        if interval != "1d":
            return await self._client.get_stock_candles(
                ticker,
                limit=limit,
                range_=range_,
                interval=interval,
            )

        if br_proventos_service.uses_bolsai and prefer_bolsai_candles(range_=range_, limit=limit):
            try:
                payload = await br_proventos_service._bolsai.get_stock_history(
                    ticker,
                    limit=limit,
                )
                if payload:
                    mapped = map_bolsai_stock_candles(ticker, payload, limit=limit)
                    if mapped.candles:
                        return mapped
            except Exception:
                pass

        return await self._client.get_stock_candles(
            ticker,
            limit=limit,
            range_=range_,
            interval=interval,
        )

    async def _get_fundamental_history_hybrid(
        self,
        ticker: str,
        *,
        limit: int,
    ) -> StockFundamentalHistoryResponse:
        if br_proventos_service.uses_bolsai:
            try:
                payload = await br_proventos_service._bolsai.get_fundamentals_history(
                    ticker,
                    limit=limit,
                )
                if payload:
                    mapped = map_bolsai_fundamental_history(ticker, payload, limit=limit)
                    if mapped.periods:
                        return mapped
            except Exception:
                pass

        return await self._client.get_stock_fundamental_history(ticker, limit=limit)

    async def _get_screener_bolsai_hybrid(
        self,
        *,
        search: str | None,
        sort_by: str,
        sort_order: str,
        limit: int,
        page: int,
        min_dividend_yield: float | None = None,
        max_dividend_yield: float | None = None,
        min_price_earnings: float | None = None,
        max_price_earnings: float | None = None,
        min_return_on_equity: float | None = None,
        max_return_on_equity: float | None = None,
        min_price_to_book: float | None = None,
        max_price_to_book: float | None = None,
    ) -> StockScreenerResponse:
        from app.clients.bolsai.screener_mapper import (
            build_bolsai_screener_params,
            map_bolsai_screener,
        )

        params = build_bolsai_screener_params(
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
        payload = await br_proventos_service._bolsai.get_screener(params=params)
        if not payload:
            return StockScreenerResponse(items=[], count=0, total=0, page=page, provider="hybrid")
        result = map_bolsai_screener(payload, page=page, limit=limit, search=search)
        return await self._enrich_screener_market_data_from_brapi(result)

    async def _enrich_screener_market_data_from_brapi(
        self,
        result: StockScreenerResponse,
    ) -> StockScreenerResponse:
        from app.clients.brapi.stock_mapper import resolve_logo_url

        symbols = [item.symbol for item in result.items]
        if not symbols:
            return result
        try:
            raw_items = await self._client.get_quotes_raw(symbols)
        except UpstreamError:
            return result
        by_symbol: dict[str, dict] = {}
        for raw in raw_items:
            symbol = str(raw.get("symbol") or raw.get("stock") or "").upper().strip()
            if symbol:
                by_symbol[symbol] = raw
        items = []
        for item in result.items:
            raw = by_symbol.get(item.symbol)
            if not raw:
                items.append(item)
                continue
            price_raw = raw.get("regularMarketPrice", raw.get("close"))
            change_raw = raw.get("regularMarketChangePercent", raw.get("change"))
            volume_raw = raw.get("regularMarketVolume", raw.get("volume"))
            items.append(
                item.model_copy(
                    update={
                        "price": float(price_raw) if price_raw is not None else item.price,
                        "change_percent": float(change_raw) if change_raw is not None else item.change_percent,
                        "volume": float(volume_raw) if volume_raw is not None else item.volume,
                        "logo_url": resolve_logo_url(item.symbol, raw.get("logourl") or raw.get("logo")),
                    }
                )
            )
        return result.model_copy(update={"items": items})

    async def _get_financials_hybrid(
        self,
        ticker: str,
        *,
        limit: int,
        period: str,
    ) -> StockFinancialsResponse:
        if br_proventos_service.uses_bolsai:
            try:
                from app.clients.bolsai.financials_mapper import map_bolsai_financials

                financials_payload, history_payload = await asyncio.gather(
                    br_proventos_service._bolsai.get_financials(ticker, period=period),
                    br_proventos_service._bolsai.get_fundamentals_history(ticker, limit=limit),
                    return_exceptions=True,
                )
                if isinstance(financials_payload, Exception):
                    financials_payload = None
                if isinstance(history_payload, Exception):
                    history_payload = None
                if financials_payload:
                    mapped = map_bolsai_financials(
                        ticker,
                        financials_payload,
                        limit=limit,
                        period=period,
                        fundamentals_history=history_payload
                        if isinstance(history_payload, dict)
                        else None,
                    )
                    if not mapped.is_empty():
                        return mapped
            except Exception:
                pass

        return await self._client.get_stock_financials(ticker, limit=limit, period=period)


quote_service = QuoteService()
