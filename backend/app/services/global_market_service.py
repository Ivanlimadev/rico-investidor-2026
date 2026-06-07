from __future__ import annotations

import asyncio

from app.clients.brapi.models import MarketQuote, MarketQuoteBatchResponse, StockCompareItem, StockCompareResponse
from app.clients.fmp.client import FmpClient
from app.clients.fmp.fundamentals_mapper import map_fundamentals_from_fmp
from app.clients.fmp.profile_mapper import fmp_company_updates, fmp_market_cap
from app.clients.marketstack.client import MarketstackClient
from app.clients.marketstack.stock_mapper import with_us_logo
from app.config import settings
from app.core.cache import StaleTtlCache, TtlCache
from app.core.disk_cache import DailyCallBudget, DiskJsonCache, NegativeCache
from app.core.exceptions import NotConfiguredError, UpstreamError
from app.domain.global_markets.fundamentals import (
    build_market_stats_from_quote,
    enrich_company_profile,
    merge_fundamentals,
    to_stock_profile,
    unwrap_tickerinfo_payload,
)
from app.domain.global_markets.dividend_analytics import enrich_dividend_dates
from app.domain.global_markets.analytics import (
    build_company_profile,
    compute_returns,
    summarize_dividends,
)
from app.domain.global_markets.models import (
    CountryExchangesGroup,
    CountryHubResponse,
    CountryHubSection,
    ExchangeMarketListResponse,
    GlobalMarketCapabilitiesResponse,
    GlobalStockCandlesResponse,
    GlobalStockDetailResponse,
    GlobalStockExploreResponse,
    GlobalStockIntradayCandlesResponse,
    GlobalStockTickerInfo,
    WorldExchangesResponse,
)
from app.domain.global_markets.us_market_session import quote_cache_ttl_seconds, us_market_session
from app.domain.market_heatmap.presets import (
    DEFAULT_HEATMAP_LIMIT,
    MAX_HEATMAP_LIMIT,
    MIN_US_STOCK_HEATMAP_VOLUME,
    US_HEATMAP_EOD_BATCH_SIZE,
    US_HEATMAP_FETCH_COUNT,
    US_HEATMAP_LOOKBACK_DAYS,
    US_NASDAQ_HEATMAP_CANDIDATES,
    US_PRIMARY_EXCHANGE_MIC,
)
from app.domain.global_markets.regions import (
    ENABLED_MARKET_COUNTRY_CODES,
    is_market_country_enabled,
    require_exchange_mic,
    require_market_country,
)
from app.domain.global_markets.presets import (
    FEATURED_US_TICKERS,
    PRIORITY_COUNTRY_CODES,
    US_EXCHANGES,
    US_REITS_SEGMENTS,
    US_STOCK_SEGMENTS,
    US_TICKER_NAMES,
    adr_ticker_name,
    country_display_name,
    country_exchange_segments,
    country_hub_preset,
    is_adr_backed_country,
)
from app.providers.marketstack_capabilities import marketstack_capabilities


class GlobalMarketService:
    """Mercados globais via Marketstack — plano configurável (basic, business, etc.)."""

    def __init__(
        self,
        client: MarketstackClient | None = None,
        *,
        fmp_client: FmpClient | None = None,
    ) -> None:
        self._client = client or MarketstackClient()
        self._fmp = fmp_client or FmpClient()
        caps = marketstack_capabilities()
        quote_ttl = (
            settings.marketstack_realtime_cache_ttl_seconds
            if caps.realtime_enabled
            else settings.quote_cache_ttl_seconds
        )
        long_ttl = quote_ttl * 24
        self._featured_cache: StaleTtlCache[MarketQuoteBatchResponse] = StaleTtlCache(quote_ttl)
        heatmap_ttl = max(quote_ttl * 2, 600)
        self._heatmap_cache: StaleTtlCache[MarketQuoteBatchResponse] = StaleTtlCache(heatmap_ttl)
        self._explore_cache: StaleTtlCache[GlobalStockExploreResponse] = StaleTtlCache(quote_ttl)
        self._candles_cache: StaleTtlCache[GlobalStockCandlesResponse] = StaleTtlCache(quote_ttl * 2)
        self._intraday_cache: StaleTtlCache[GlobalStockIntradayCandlesResponse] = StaleTtlCache(quote_ttl)
        self._exchanges_cache: TtlCache[WorldExchangesResponse] = TtlCache(long_ttl)
        self._exchange_market_cache: StaleTtlCache[ExchangeMarketListResponse] = StaleTtlCache(quote_ttl)
        self._us_market_cache: StaleTtlCache[ExchangeMarketListResponse] = StaleTtlCache(quote_ttl * 6)
        self._country_market_cache: StaleTtlCache[ExchangeMarketListResponse] = StaleTtlCache(quote_ttl * 6)
        self._country_hub_cache: StaleTtlCache[CountryHubResponse] = StaleTtlCache(quote_ttl)
        self._exchange_totals_cache: TtlCache[int] = TtlCache(long_ttl)
        self._detail_cache: StaleTtlCache[GlobalStockDetailResponse] = StaleTtlCache(quote_ttl * 2)
        self._compare_cache: StaleTtlCache[StockCompareResponse] = StaleTtlCache(quote_ttl * 2)
        # Proteção do plano gratuito FMP (250/dia): memória → disco → cache negativo
        # → teto diário persistente. Logos não dependem disto (endpoint público).
        self._fmp_profile_cache: TtlCache[dict] = TtlCache(settings.fmp_profile_cache_ttl_seconds)
        self._fmp_profile_disk = DiskJsonCache(
            settings.fmp_cache_dir / "profiles",
            ttl_seconds=settings.fmp_profile_cache_ttl_seconds,
        )
        self._fmp_ratios_cache: TtlCache[dict] = TtlCache(settings.fmp_profile_cache_ttl_seconds)
        self._fmp_ratios_disk = DiskJsonCache(
            settings.fmp_cache_dir / "ratios_ttm",
            ttl_seconds=settings.fmp_profile_cache_ttl_seconds,
        )
        self._fmp_metrics_cache: TtlCache[dict] = TtlCache(settings.fmp_profile_cache_ttl_seconds)
        self._fmp_metrics_disk = DiskJsonCache(
            settings.fmp_cache_dir / "key_metrics_ttm",
            ttl_seconds=settings.fmp_profile_cache_ttl_seconds,
        )
        self._fmp_negative = NegativeCache(settings.fmp_negative_cache_ttl_seconds)
        self._fmp_budget = DailyCallBudget(
            settings.fmp_daily_request_budget,
            state_path=settings.fmp_cache_dir / "budget.json",
        )

    @staticmethod
    def _with_logo(quote: MarketQuote) -> MarketQuote:
        return with_us_logo(quote)

    @staticmethod
    def _live_intraday_enabled() -> bool:
        """Intraday só durante pré/pregão/after — evita preço obsoleto no fim de semana."""
        from app.domain.global_markets.quote_reconcile import should_reconcile_quotes_to_eod

        return not should_reconcile_quotes_to_eod()

    def _quote_kwargs(self) -> dict:
        caps = marketstack_capabilities()
        return {
            "use_intraday": caps.realtime_enabled and self._live_intraday_enabled(),
            "intraday_interval": caps.intraday_interval or settings.marketstack_intraday_interval,
        }

    def _refresh_seconds(self) -> int:
        caps = marketstack_capabilities()
        return quote_cache_ttl_seconds(
            realtime_enabled=caps.realtime_enabled,
            base_realtime=settings.marketstack_realtime_cache_ttl_seconds,
            base_eod=settings.quote_cache_ttl_seconds,
        )

    async def _overlay_live_intraday_prices(
        self,
        quotes: list[MarketQuote],
        *,
        exchange: str | None = None,
    ) -> list[MarketQuote]:
        caps = marketstack_capabilities()
        if not caps.realtime_enabled or not self._live_intraday_enabled() or not quotes:
            return quotes

        from app.clients.marketstack.stock_mapper import (
            filter_today_intraday_rows,
            normalize_marketstack_symbol,
            overlay_intraday_prices,
        )

        symbols = [normalize_marketstack_symbol(quote.symbol) for quote in quotes]
        intraday_rows = await self._safe_upstream(
            self._client.get_intraday_latest(
                symbols,
                interval=caps.intraday_interval or settings.marketstack_intraday_interval,
                exchange=exchange,
            ),
            default=[],
        )
        intraday_rows = filter_today_intraday_rows(intraday_rows or [])
        if not intraday_rows:
            return quotes
        return overlay_intraday_prices(quotes, intraday_rows)

    async def _finalize_batch_quotes(
        self,
        quotes: list[MarketQuote],
        *,
        eod_rows: list[dict] | None = None,
        exchange: str | None = None,
    ) -> list[MarketQuote]:
        from app.domain.global_markets.quote_reconcile import (
            reconcile_quotes_from_eod_rows,
            should_reconcile_quotes_to_eod,
        )

        if should_reconcile_quotes_to_eod() and eod_rows:
            return reconcile_quotes_from_eod_rows(quotes, eod_rows)
        return await self._overlay_live_intraday_prices(quotes, exchange=exchange)

    def capabilities(self) -> GlobalMarketCapabilitiesResponse:
        caps = marketstack_capabilities()
        refresh = self._refresh_seconds()
        session = us_market_session()
        intraday_delay = (
            settings.marketstack_intraday_delay_minutes
            if caps.realtime_enabled and settings.marketstack_intraday_delay_minutes > 0
            else None
        )
        return GlobalMarketCapabilitiesResponse(
            plan=caps.plan.value,
            data_mode=caps.data_mode,
            max_history_days=caps.max_history_days,
            realtime_enabled=caps.realtime_enabled,
            fundamentals_enabled=caps.fundamentals_enabled,
            monthly_request_budget=caps.monthly_request_budget,
            intraday_interval=caps.intraday_interval,
            refresh_seconds=refresh,
            api_configured=self._client.configured,
            enabled_country_codes=list(ENABLED_MARKET_COUNTRY_CODES),
            global_markets_expanded=False,
            us_market_status=str(session["status"]),
            us_market_open=bool(session["is_open"]),
            us_market_label=str(session["label"]),
            us_market_timezone=str(session["timezone"]),
            us_market_holiday=bool(session.get("is_holiday")),
            intraday_delay_minutes=intraday_delay,
        )

    def _order_quotes(self, symbols: list[str], quotes: list[MarketQuote]) -> list[MarketQuote]:
        by_symbol = {quote.symbol: quote for quote in quotes}
        return [by_symbol[symbol] for symbol in symbols if symbol in by_symbol]

    async def list_featured_us(self) -> MarketQuoteBatchResponse:
        cache_key = "featured_us:v2"
        cached = self._featured_cache.get(cache_key)
        if cached:
            return cached

        try:
            from app.clients.marketstack.stock_mapper import (
                map_eod_quotes_with_change,
                sparklines_from_eod_items,
            )

            symbols = list(FEATURED_US_TICKERS)
            eod_rows = await self._fetch_eod_rows(
                symbols,
                exchange=US_PRIMARY_EXCHANGE_MIC,
                chunk_size=max(len(symbols), 8),
                lookback_days=90,
            )
            spark_map = sparklines_from_eod_items(eod_rows)
            quotes = map_eod_quotes_with_change(eod_rows, category="stocks") if eod_rows else []
            if not quotes:
                quotes = await self._client.map_quotes_with_change(
                    symbols,
                    category="stocks",
                    **self._quote_kwargs(),
                )
            items = self._order_quotes(symbols, quotes)
            items = [
                self._with_logo(
                    item.model_copy(
                        update={
                            "sparkline": self._sparkline_for_quote(item, spark_map),
                        }
                    )
                )
                for item in items
            ]
            items = await self._finalize_batch_quotes(
                items,
                eod_rows=eod_rows or None,
                exchange=US_PRIMARY_EXCHANGE_MIC,
            )
            items = [self._with_logo(item) for item in items]
            result = MarketQuoteBatchResponse(items=items, count=len(items), provider="marketstack")
            self._featured_cache.set(cache_key, result)
            return result
        except UpstreamError:
            stale = self._featured_cache.get_last_good(cache_key)
            if stale is not None:
                return stale
            raise

    async def _us_heatmap_quotes_from_latest(
        self,
        symbols: list[str],
        *,
        exchange: str,
        rows: list[dict] | None = None,
    ) -> list[MarketQuote]:
        """Fallback rápido — uma chamada ``eod/latest`` (sem variação se faltar histórico)."""
        from app.clients.marketstack.stock_mapper import map_eod_quote

        if rows is None:
            rows = await self._safe_upstream(
                self._client.get_eod_latest(symbols, exchange=exchange),
                default=[],
            )
        quotes: list[MarketQuote] = []
        for row in rows or []:
            quote = map_eod_quote(row, category="stocks")
            if quote is not None:
                quotes.append(quote.model_copy(update={"exchange": exchange}))
        return quotes

    async def _build_us_heatmap_items(
        self,
        *,
        exchange: str,
        safe_limit: int,
    ) -> list[MarketQuote]:
        from app.clients.marketstack.stock_mapper import map_eod_quotes_with_change

        fetch_symbols = list(US_NASDAQ_HEATMAP_CANDIDATES[:US_HEATMAP_FETCH_COUNT])
        eod_rows = await self._fetch_eod_rows(
            fetch_symbols,
            exchange=exchange,
            chunk_size=US_HEATMAP_EOD_BATCH_SIZE,
            lookback_days=US_HEATMAP_LOOKBACK_DAYS,
        )
        reconcile_rows: list[dict] = list(eod_rows)
        quotes = map_eod_quotes_with_change(eod_rows, category="stocks")
        if not quotes:
            fallback_symbols = list(FEATURED_US_TICKERS)[:US_HEATMAP_FETCH_COUNT]
            eod_rows = await self._fetch_eod_rows(
                fallback_symbols,
                exchange=exchange,
                chunk_size=len(fallback_symbols),
                lookback_days=US_HEATMAP_LOOKBACK_DAYS,
            )
            reconcile_rows = list(eod_rows)
            quotes = map_eod_quotes_with_change(eod_rows, category="stocks")
        if not quotes:
            latest_rows = await self._safe_upstream(
                self._client.get_eod_latest(fetch_symbols, exchange=exchange),
                default=[],
            )
            reconcile_rows = list(latest_rows or [])
            quotes = await self._us_heatmap_quotes_from_latest(
                fetch_symbols,
                exchange=exchange,
                rows=reconcile_rows,
            )

        ranked = sorted(quotes, key=lambda quote: quote.volume or 0.0, reverse=True)
        items = [
            self._with_logo(quote.model_copy(update={"exchange": exchange}))
            for quote in ranked
            if (quote.volume or 0) >= MIN_US_STOCK_HEATMAP_VOLUME
        ][:safe_limit]
        if not items and ranked:
            items = [
                self._with_logo(quote.model_copy(update={"exchange": exchange}))
                for quote in ranked[:safe_limit]
            ]
        return await self._finalize_batch_quotes(
            items,
            eod_rows=reconcile_rows or None,
            exchange=exchange,
        )

    async def get_us_heatmap(
        self,
        *,
        exchange: str = US_PRIMARY_EXCHANGE_MIC,
        limit: int = DEFAULT_HEATMAP_LIMIT,
    ) -> MarketQuoteBatchResponse:
        """Mapa de calor EUA — bolsa principal (NASDAQ) rankeada por volume EOD."""
        normalized_exchange = exchange.upper().strip() or US_PRIMARY_EXCHANGE_MIC
        safe_limit = max(1, min(limit, MAX_HEATMAP_LIMIT))
        cache_key = f"us_heatmap:{normalized_exchange}:{safe_limit}"
        cached = self._heatmap_cache.get(cache_key)
        if cached:
            return cached

        try:
            items = await self._build_us_heatmap_items(
                exchange=normalized_exchange,
                safe_limit=safe_limit,
            )
            result = MarketQuoteBatchResponse(
                items=items,
                count=len(items),
                provider="marketstack",
            )
            if items:
                self._heatmap_cache.set(cache_key, result)
            return result
        except Exception:
            stale = self._heatmap_cache.get_last_good(cache_key)
            if stale is not None:
                return stale
            return MarketQuoteBatchResponse(items=[], count=0, provider="marketstack")

    async def explore(
        self,
        *,
        category: str = "stocks",
        page: int = 1,
        limit: int = 30,
        search: str | None = None,
    ) -> GlobalStockExploreResponse:
        normalized = category.strip().lower() or "stocks"
        safe_page = max(1, page)
        safe_limit = max(1, min(limit, 50))
        listing = await self.list_us_market(
            category=normalized,
            page=safe_page,
            limit=safe_limit,
            search=search,
        )
        return GlobalStockExploreResponse(
            items=listing.items,
            count=listing.count,
            total=listing.total or listing.count,
            page=listing.page,
            category=normalized,
            data_mode=listing.data_mode,
        )

    @staticmethod
    def _us_segments(category: str) -> tuple[tuple[str, str], ...]:
        return US_REITS_SEGMENTS if category == "reits" else US_STOCK_SEGMENTS

    async def _exchange_totals_map(
        self,
        segments: tuple[tuple[str, str], ...],
    ) -> dict[str, int]:
        if not segments:
            return {}
        mics = [mic.upper() for mic, _name in segments]
        totals = await asyncio.gather(
            *[self._exchange_ticker_total(mic) for mic in mics],
        )
        return dict(zip(mics, totals))

    async def _exchange_ticker_total(self, mic: str) -> int:
        normalized_mic = mic.upper().strip()
        cache_key = f"exchange_total:{normalized_mic}"
        cached = self._exchange_totals_cache.get(cache_key)
        if cached is not None:
            return cached

        total = 0
        try:
            _, pagination = await self._client.list_exchange_tickers(normalized_mic, limit=1, offset=0)
            total = self._pagination_total(pagination) or 0
        except UpstreamError:
            pass

        if total == 0:
            try:
                _, pagination = await self._client.get_exchange_eod(normalized_mic, limit=1, offset=0)
                total = self._pagination_total(pagination) or 0
            except UpstreamError:
                total = 0

        self._exchange_totals_cache.set(cache_key, total)
        return total

    async def _fetch_exchange_quotes(
        self,
        mic: str,
        *,
        offset: int,
        limit: int,
        search: str | None,
        category: str,
    ) -> tuple[list[MarketQuote], dict]:
        normalized_mic = mic.upper().strip()
        safe_limit = max(1, min(limit, 50))
        safe_offset = max(0, offset)
        empty_pagination = {"total": 0, "limit": safe_limit, "offset": safe_offset}
        try:
            rows, pagination = await self._client.list_exchange_tickers(
                normalized_mic,
                limit=safe_limit,
                offset=safe_offset,
                search=search,
            )
        except UpstreamError:
            if search:
                return [], empty_pagination
            rows = []
            pagination = empty_pagination

        quotes = (
            await self._quotes_from_ticker_rows(rows, exchange=normalized_mic, category=category)
            if rows
            else []
        )
        return quotes, pagination

    async def _paginate_us_segments(
        self,
        segments: tuple[tuple[str, str], ...],
        *,
        page: int,
        limit: int,
        category: str,
    ) -> tuple[list[MarketQuote], int]:
        if page == 1 and limit >= 20 and segments:
            mic, _name = segments[0]
            quotes, pagination = await self._fetch_exchange_quotes(
                mic,
                offset=0,
                limit=limit,
                search=None,
                category=category,
            )
            page_total = self._pagination_total(pagination)
            asyncio.create_task(self._exchange_totals_map(segments))
            return quotes, page_total or len(quotes)

        totals_map = await self._exchange_totals_map(segments)
        offset = (page - 1) * limit
        skip = offset
        need = limit
        items: list[MarketQuote] = []

        for mic, _name in segments:
            if need <= 0:
                break
            total = totals_map.get(mic.upper(), 0)
            if skip >= total:
                skip -= total
                continue
            quotes, _pagination = await self._fetch_exchange_quotes(
                mic,
                offset=skip,
                limit=need,
                search=None,
                category=category,
            )
            skip = 0
            need -= len(quotes)
            items.extend(quotes)

        return items, sum(totals_map.values())

    async def _search_us_segments(
        self,
        segments: tuple[tuple[str, str], ...],
        *,
        search: str,
        page: int,
        limit: int,
        category: str,
    ) -> tuple[list[MarketQuote], int]:
        merged: list[MarketQuote] = []
        seen: set[str] = set()
        fetch_limit = min(50, max(limit * page, limit))

        results = await asyncio.gather(
            *[
                self._fetch_exchange_quotes(
                    mic,
                    offset=0,
                    limit=fetch_limit,
                    search=search,
                    category=category,
                )
                for mic, _name in segments
            ],
        )
        for quotes, _pagination in results:
            for quote in quotes:
                if quote.symbol in seen:
                    continue
                seen.add(quote.symbol)
                merged.append(quote)

        merged.sort(key=lambda quote: quote.symbol)
        start = (page - 1) * limit
        page_items = merged[start : start + limit]
        return page_items, len(merged)

    async def list_us_market(
        self,
        *,
        category: str = "stocks",
        page: int = 1,
        limit: int = 25,
        search: str | None = None,
    ) -> ExchangeMarketListResponse:
        normalized = category.strip().lower() or "stocks"
        safe_page = max(1, page)
        safe_limit = max(1, min(limit, 50))
        search_key = (search or "").strip()
        cache_key = f"us_market:v2:{normalized}:{safe_page}:{safe_limit}:{search_key.lower()}"
        cached = self._us_market_cache.get(cache_key)
        if cached:
            return cached

        try:
            segments = self._us_segments(normalized)
            caps = marketstack_capabilities()
            if search_key:
                items, total = await self._search_us_segments(
                    segments,
                    search=search_key,
                    page=safe_page,
                    limit=safe_limit,
                    category=normalized,
                )
            else:
                items, total = await self._paginate_us_segments(
                    segments,
                    page=safe_page,
                    limit=safe_limit,
                    category=normalized,
                )

            label = "REITs — NYSE" if normalized == "reits" else "Mercado Americano"
            result = ExchangeMarketListResponse(
                exchange_mic="US",
                exchange_name=label,
                country_code="US",
                items=items,
                count=len(items),
                total=total,
                page=safe_page,
                limit=safe_limit,
                data_mode=caps.data_mode,
            )
            self._us_market_cache.set(cache_key, result)
            return result
        except UpstreamError:
            stale = self._us_market_cache.get_last_good(cache_key)
            if stale is not None:
                return stale
            raise

    async def count_us_stocks(self) -> int:
        total = 0
        for mic, _name in US_STOCK_SEGMENTS:
            total += await self._exchange_ticker_total(mic)
        return total

    async def get_quote(self, symbol: str, *, exchange: str | None = None) -> MarketQuote:
        from app.domain.global_markets.quote_reconcile import (
            reconcile_quote_with_candles,
            should_reconcile_quotes_to_eod,
        )

        normalized = symbol.upper().strip()
        attempts: list[str | None] = []
        if exchange:
            attempts.append(exchange.upper())
        attempts.append(None)

        quote: MarketQuote | None = None
        resolved_exchange: str | None = exchange
        for mic in attempts:
            quotes = await self._client.map_quotes_with_change(
                [normalized],
                category="stocks",
                exchange=mic,
                **self._quote_kwargs(),
            )
            if quotes:
                quote = quotes[0]
                resolved_exchange = exchange or quote.exchange or mic
                break

        if quote is None:
            raise UpstreamError(f"Cotação não encontrada: {normalized}", status_code=404)

        if should_reconcile_quotes_to_eod():
            try:
                candles_resp = await self.get_candles(
                    normalized,
                    exchange=resolved_exchange,
                    limit=12,
                )
                if candles_resp.candles:
                    quote = reconcile_quote_with_candles(quote, candles_resp.candles)
            except UpstreamError:
                pass

        return self._with_logo(quote)

    async def get_candles(
        self,
        symbol: str,
        *,
        exchange: str | None = None,
        limit: int = 252,
    ) -> GlobalStockCandlesResponse:
        normalized = symbol.upper().strip()
        resolved_exchange = exchange
        if not resolved_exchange:
            quote = await self.get_quote(normalized)
            resolved_exchange = quote.exchange

        caps = marketstack_capabilities()
        safe_limit = max(1, min(limit, 1000))
        # Janela do plano inteira para o cliente recortar 3M/6M/1A (~66/132/252 pregões).
        lookback_days = caps.max_history_days
        cache_key = f"candles:{normalized}:{resolved_exchange}:{safe_limit}:{lookback_days}"
        cached = self._candles_cache.get(cache_key)
        if cached:
            return cached

        from app.clients.marketstack.stock_mapper import history_date_from

        date_from = history_date_from(max_history_days=lookback_days)
        candles = await self._client.map_candles(
            normalized,
            date_from=date_from,
            exchange=resolved_exchange,
            limit=safe_limit,
        )
        if len(candles) > safe_limit:
            candles = candles[-safe_limit:]

        result = GlobalStockCandlesResponse(
            symbol=normalized,
            exchange=resolved_exchange,
            candles=candles,
            count=len(candles),
            history_limited=caps.plan.value == "free",
            max_history_days=caps.max_history_days,
            data_mode=caps.data_mode,
        )
        self._candles_cache.set(cache_key, result)
        return result

    async def get_intraday_candles(
        self,
        symbol: str,
        *,
        exchange: str | None = None,
        limit: int = 500,
    ) -> GlobalStockIntradayCandlesResponse:
        from datetime import datetime
        from zoneinfo import ZoneInfo

        from app.clients.marketstack.stock_mapper import map_eod_candles, normalize_marketstack_symbol

        normalized = symbol.upper().strip()
        caps = marketstack_capabilities()
        interval = caps.intraday_interval or settings.marketstack_intraday_interval
        safe_limit = max(10, min(limit, 1000))
        cache_key = f"intraday:{normalized}:{exchange}:{interval}:{safe_limit}"
        cached = self._intraday_cache.get(cache_key)
        if cached:
            return cached

        if not caps.realtime_enabled:
            return GlobalStockIntradayCandlesResponse(
                symbol=normalized,
                exchange=exchange,
                interval=interval,
                data_mode=caps.data_mode,
            )

        ny = ZoneInfo("America/New_York")
        today = datetime.now(ny).date().isoformat()
        resolved_exchange = exchange
        if not resolved_exchange:
            try:
                quote = await self.get_quote(normalized)
                resolved_exchange = quote.exchange
            except UpstreamError:
                resolved_exchange = None

        rows = await self._safe_upstream(
            self._client.get_intraday(
                [normalize_marketstack_symbol(normalized)],
                interval=interval,
                date_from=today,
                exchange=resolved_exchange,
                limit=safe_limit,
                sort="ASC",
            ),
            default=[],
        )
        candles = map_eod_candles(rows or [])
        result = GlobalStockIntradayCandlesResponse(
            symbol=normalized,
            exchange=resolved_exchange,
            candles=candles,
            count=len(candles),
            interval=interval,
            data_mode=caps.data_mode,
        )
        if candles:
            self._intraday_cache.set(cache_key, result)
        return result

    @staticmethod
    async def _safe_upstream(coro, *, default=None):
        try:
            return await coro
        except Exception:
            return default

    async def _fetch_fmp_profile(self, symbol: str) -> dict | None:
        """Perfil FMP protegido contra estouro de cota (enriquecimento opcional).

        Ordem: memória → disco (persistente) → cache negativo → teto diário → rede.
        Nunca levanta erro: na pior hipótese devolve ``None`` e o detalhe segue
        normalmente com os dados da Marketstack.
        """
        cache_key = symbol.upper().strip()
        if not cache_key:
            return None

        cached = self._fmp_profile_cache.get(cache_key)
        if cached is not None:
            return cached

        on_disk = self._fmp_profile_disk.get(cache_key)
        if on_disk is not None:
            self._fmp_profile_cache.set(cache_key, on_disk)
            return on_disk

        if self._fmp_negative.is_blocked(cache_key):
            return None
        if not self._fmp.configured:
            return None
        # Teto diário atingido — serve só do cache, sem novas chamadas.
        if not self._fmp_budget.allow():
            return None

        try:
            profile = await self._fmp.get_company_profile(symbol)
        except Exception:
            # Falha transitória (rede/429/5xx/chave): conta a tentativa e tenta
            # de novo no futuro, sem envenenar o cache negativo.
            self._fmp_budget.record()
            return None

        self._fmp_budget.record()

        if isinstance(profile, dict) and profile:
            self._fmp_profile_cache.set(cache_key, profile)
            self._fmp_profile_disk.set(cache_key, profile)
            return profile

        # Não existe perfil para este símbolo — evita re-consultar por um período.
        self._fmp_negative.mark(cache_key)
        return None

    async def _fetch_fmp_ratios_ttm(self, symbol: str) -> dict | None:
        cache_key = symbol.upper().strip()
        if not cache_key:
            return None

        cached = self._fmp_ratios_cache.get(cache_key)
        if cached is not None:
            return cached

        on_disk = self._fmp_ratios_disk.get(cache_key)
        if on_disk is not None:
            self._fmp_ratios_cache.set(cache_key, on_disk)
            return on_disk

        if self._fmp_negative.is_blocked(f"ratios:{cache_key}"):
            return None
        if not self._fmp.configured:
            return None
        if not self._fmp_budget.allow():
            return None

        try:
            ratios = await self._fmp.get_ratios_ttm(symbol)
        except Exception:
            self._fmp_budget.record()
            return None

        self._fmp_budget.record()

        if isinstance(ratios, dict) and ratios:
            self._fmp_ratios_cache.set(cache_key, ratios)
            self._fmp_ratios_disk.set(cache_key, ratios)
            return ratios

        self._fmp_negative.mark(f"ratios:{cache_key}")
        return None

    async def _fetch_fmp_key_metrics_ttm(self, symbol: str) -> dict | None:
        cache_key = symbol.upper().strip()
        if not cache_key:
            return None

        cached = self._fmp_metrics_cache.get(cache_key)
        if cached is not None:
            return cached

        on_disk = self._fmp_metrics_disk.get(cache_key)
        if on_disk is not None:
            self._fmp_metrics_cache.set(cache_key, on_disk)
            return on_disk

        if self._fmp_negative.is_blocked(f"metrics:{cache_key}"):
            return None
        if not self._fmp.configured:
            return None
        if not self._fmp_budget.allow():
            return None

        try:
            metrics = await self._fmp.get_key_metrics_ttm(symbol)
        except Exception:
            self._fmp_budget.record()
            return None

        self._fmp_budget.record()

        if isinstance(metrics, dict) and metrics:
            self._fmp_metrics_cache.set(cache_key, metrics)
            self._fmp_metrics_disk.set(cache_key, metrics)
            return metrics

        self._fmp_negative.mark(f"metrics:{cache_key}")
        return None

    async def _enrich_fundamentals_with_fmp(
        self,
        fundamentals,
        *,
        symbol: str,
        fmp_profile: dict | None,
        price: float | None,
        marketstack_has_ratios: bool,
    ):
        if marketstack_has_ratios:
            return fundamentals
        if not self._fmp.configured:
            return fundamentals
        ratios, metrics = await asyncio.gather(
            self._fetch_fmp_ratios_ttm(symbol),
            self._fetch_fmp_key_metrics_ttm(symbol),
        )
        return map_fundamentals_from_fmp(
            fundamentals,
            profile=fmp_profile,
            ratios_ttm=ratios,
            key_metrics_ttm=metrics,
            price=price,
        )

    async def get_stock_detail(
        self,
        symbol: str,
        *,
        exchange: str | None = None,
        candle_limit: int = 252,
        dividend_limit: int = 100,
        split_limit: int = 50,
        category: str = "stocks",
        include_extras: bool = True,
    ) -> GlobalStockDetailResponse:
        from app.clients.marketstack.stock_mapper import (
            map_dividends,
            map_eod_quote,
            map_splits,
            map_ticker_info,
        )

        normalized = symbol.upper().strip()
        safe_candles = max(30, min(candle_limit, 1000))
        safe_dividends = max(1, min(dividend_limit, 500))
        cache_key = (
            f"detail:v5:{normalized}:{exchange}:{safe_candles}:"
            f"{safe_dividends}:{split_limit}:{include_extras}"
        )
        cached = self._detail_cache.get(cache_key)
        if cached:
            return cached

        try:
            caps = marketstack_capabilities()

            candles_resp = await self._safe_upstream(
                self.get_candles(normalized, exchange=exchange, limit=safe_candles),
                default=None,
            )
            if candles_resp is None or not candles_resp.candles:
                candles_resp = await self._safe_upstream(
                    self.get_candles(normalized, exchange=None, limit=safe_candles),
                    default=GlobalStockCandlesResponse(
                        symbol=normalized,
                        exchange=exchange,
                        candles=[],
                        count=0,
                        history_limited=caps.plan.value == "free",
                        max_history_days=caps.max_history_days,
                        data_mode=caps.data_mode,
                    ),
                )

            resolved_exchange = exchange or candles_resp.exchange

            async def fetch_dividends():
                if not include_extras:
                    return [], {}
                if safe_dividends <= 100:
                    return await self._client.get_ticker_dividends(normalized, limit=safe_dividends)
                return await self._client.get_ticker_dividends_paginated(
                    normalized,
                    limit=safe_dividends,
                )

            async def empty_pairs():
                return [], {}

            async def empty_optional():
                return None

            async def fetch_splits():
                if not include_extras:
                    return [], {}
                safe_splits = max(1, min(split_limit, 500))
                if safe_splits <= 100:
                    return await self._client.get_ticker_splits(normalized, limit=safe_splits)
                return await self._client.get_ticker_splits_paginated(
                    normalized,
                    limit=safe_splits,
                )

            parallel = [
                self._safe_upstream(fetch_dividends(), default=([], {})),
                self._safe_upstream(fetch_splits(), default=([], {}))
                if include_extras
                else self._safe_upstream(empty_pairs(), default=([], {})),
                self._safe_upstream(self._client.get_ticker(normalized), default=None),
                self._safe_upstream(self._client.get_ticker_eod_latest(normalized), default=None),
                self._safe_upstream(self._client.get_ticker_info_v2(normalized), default=None)
                if caps.fundamentals_enabled
                else self._safe_upstream(empty_optional(), default=None),
                self._fetch_fmp_profile(normalized),
            ]
            parallel_results = await asyncio.gather(*parallel)

            dividend_rows = parallel_results[0] if include_extras else ([], {})
            split_rows = parallel_results[1] if include_extras else ([], {})
            ticker_raw = parallel_results[2]
            eod_latest = parallel_results[3]
            tickerinfo_raw = parallel_results[4] if caps.fundamentals_enabled else None
            fmp_profile = parallel_results[5]
            tickerinfo = unwrap_tickerinfo_payload(tickerinfo_raw if isinstance(tickerinfo_raw, dict) else None)

            ticker_info = map_ticker_info(ticker_raw or {"symbol": normalized})
            if ticker_info is None:
                ticker_info = GlobalStockTickerInfo(
                    symbol=normalized,
                    name=US_TICKER_NAMES.get(normalized, normalized),
                    exchange_mic=resolved_exchange,
                )
            else:
                ticker_info = ticker_info.model_copy(update={"symbol": normalized})
                if resolved_exchange and not ticker_info.exchange_mic:
                    ticker_info = ticker_info.model_copy(update={"exchange_mic": resolved_exchange})
            if caps.realtime_enabled:
                ticker_info = ticker_info.model_copy(update={"has_intraday": True})

            dividend_items, dividend_pagination = dividend_rows or ([], {})
            split_items, split_pagination = split_rows or ([], {})

            previous_close = None
            if len(candles_resp.candles) >= 2:
                previous_close = candles_resp.candles[-2].close

            quote = None
            if caps.realtime_enabled:
                quote = await self._safe_upstream(
                    self.get_quote(normalized, exchange=resolved_exchange),
                    default=None,
                )
                if quote is not None:
                    quote = quote.model_copy(
                        update={
                            "name": ticker_info.name,
                            "symbol": normalized,
                            "previous_close": quote.previous_close or previous_close,
                        }
                    )

            if quote is None and isinstance(eod_latest, dict):
                quote = map_eod_quote(
                    eod_latest,
                    category=category,
                    previous_close=previous_close,
                    name=ticker_info.name,
                )
                if quote is not None:
                    quote = quote.model_copy(update={"symbol": normalized})
            if quote is None and candles_resp.candles:
                last = candles_resp.candles[-1]
                quote = map_eod_quote(
                    {
                        "symbol": normalized,
                        "close": last.close,
                        "open": last.open,
                        "high": last.high,
                        "low": last.low,
                        "volume": last.volume,
                        "date": last.date,
                        "exchange": resolved_exchange,
                    },
                    category=category,
                    previous_close=previous_close,
                    name=ticker_info.name,
                )
            if quote is None:
                quote = await self._safe_upstream(
                    self.get_quote(normalized, exchange=resolved_exchange),
                    default=None,
                )
                if quote is not None:
                    quote = quote.model_copy(update={"name": ticker_info.name, "symbol": normalized})
            if quote is None:
                raise UpstreamError(f"Cotação não encontrada: {normalized}", status_code=404)

            from app.domain.global_markets.quote_reconcile import (
                reconcile_quote_with_candles,
                should_reconcile_quotes_to_eod,
            )

            if should_reconcile_quotes_to_eod():
                quote = reconcile_quote_with_candles(quote, candles_resp.candles)

            mapped_dividends = enrich_dividend_dates(map_dividends(dividend_items))
            company = enrich_company_profile(build_company_profile(ticker_info), tickerinfo=tickerinfo)
            company = fmp_company_updates(company, fmp_profile)
            dividends_summary = summarize_dividends(mapped_dividends, price=quote.price)
            returns = compute_returns(
                candles_resp.candles,
                current_price=quote.price,
                dividends=mapped_dividends,
            )
            fundamentals = merge_fundamentals(
                tickerinfo=tickerinfo,
                dividends_summary=dividends_summary,
            )
            ms_has_ratios = bool(
                tickerinfo
                and (
                    fundamentals.price_earnings is not None
                    or fundamentals.return_on_equity is not None
                )
            )
            fundamentals = await self._enrich_fundamentals_with_fmp(
                fundamentals,
                symbol=normalized,
                fmp_profile=fmp_profile if isinstance(fmp_profile, dict) else None,
                price=quote.price,
                marketstack_has_ratios=ms_has_ratios,
            )
            market_stats = build_market_stats_from_quote(
                open=quote.open,
                high=quote.high,
                low=quote.low,
                volume=quote.volume,
                previous_close=quote.previous_close,
                tickerinfo=tickerinfo,
                fundamentals=fundamentals,
            )
            if market_stats.market_cap is None:
                fallback_cap = fmp_market_cap(fmp_profile)
                if fallback_cap is not None:
                    market_stats = market_stats.model_copy(update={"market_cap": fallback_cap})

            from app.domain.global_markets.candle_stats import enrich_market_stats_from_candles

            market_stats = enrich_market_stats_from_candles(market_stats, candles_resp.candles)
            quote = self._with_logo(quote)

            result = GlobalStockDetailResponse(
                quote=quote,
                ticker=ticker_info,
                company=company,
                candles=candles_resp.candles,
                candles_count=candles_resp.count,
                dividends=mapped_dividends,
                dividends_total=self._pagination_total(dividend_pagination) or len(dividend_items),
                dividends_summary=dividends_summary,
                returns=returns,
                splits=map_splits(split_items),
                splits_total=self._pagination_total(split_pagination) or len(split_items),
                fundamentals=fundamentals,
                market_stats=market_stats,
                plan=caps.plan.value,
                data_mode=caps.data_mode,
                max_history_days=caps.max_history_days,
                history_limited=caps.plan.value == "free",
                realtime_enabled=caps.realtime_enabled,
                intraday_interval=caps.intraday_interval,
                refresh_seconds=self._refresh_seconds(),
            )
            self._detail_cache.set(cache_key, result)
            return result
        except UpstreamError:
            stale = self._detail_cache.get_last_good(cache_key)
            if stale is not None:
                return stale
            raise

    async def _country_exchange_segments(self, country_code: str) -> tuple[tuple[str, str], ...]:
        normalized = country_code.upper().strip()
        if normalized == "US":
            return US_STOCK_SEGMENTS

        fallback = country_exchange_segments(normalized)
        world_segments: tuple[tuple[str, str], ...] = ()
        world = await self.list_world_exchanges()
        for group in [*world.priority_countries, *world.other_countries]:
            if group.country_code.upper() == normalized and group.exchanges:
                world_segments = tuple((exchange.mic, exchange.name) for exchange in group.exchanges)
                break

        seen: set[str] = set()
        merged: list[tuple[str, str]] = []
        for mic, name in (*fallback, *world_segments):
            upper = mic.upper()
            if upper not in seen:
                seen.add(upper)
                merged.append((upper, name))
        return tuple(merged)

    async def list_country_market(
        self,
        country_code: str,
        *,
        page: int = 1,
        limit: int = 25,
        search: str | None = None,
    ) -> ExchangeMarketListResponse:
        normalized = require_market_country(country_code)
        safe_page = max(1, page)
        safe_limit = max(1, min(limit, 50))
        search_key = (search or "").strip()
        cache_key = f"country_market:v2:{normalized}:{safe_page}:{safe_limit}:{search_key.lower()}"
        cached = self._country_market_cache.get(cache_key)
        if cached:
            return cached

        if normalized == "US":
            listing = await self.list_us_market(
                category="stocks",
                page=safe_page,
                limit=safe_limit,
                search=search_key or None,
            )
            result = ExchangeMarketListResponse(
                exchange_mic="US",
                exchange_name=country_display_name("US"),
                country_code="US",
                items=listing.items,
                count=listing.count,
                total=listing.total,
                page=listing.page,
                limit=listing.limit,
                data_mode=listing.data_mode,
            )
            self._country_market_cache.set(cache_key, result)
            return result

        segments = await self._country_exchange_segments(normalized)
        if not segments:
            raise UpstreamError(f"País não encontrado: {normalized}", status_code=404)

        caps = marketstack_capabilities()
        try:
            if search_key:
                items, total = await self._search_us_segments(
                    segments,
                    search=search_key,
                    page=safe_page,
                    limit=safe_limit,
                    category="stocks",
                )
            else:
                items, total = await self._paginate_us_segments(
                    segments,
                    page=safe_page,
                    limit=safe_limit,
                    category="stocks",
                )

            label = country_display_name(normalized)
            result = ExchangeMarketListResponse(
                exchange_mic=normalized,
                exchange_name=label,
                country_code=normalized,
                items=items,
                count=len(items),
                total=total,
                page=safe_page,
                limit=safe_limit,
                data_mode=caps.data_mode,
            )
            self._country_market_cache.set(cache_key, result)
            return result
        except UpstreamError:
            stale = self._country_market_cache.get_last_good(cache_key)
            if stale is not None:
                return stale
            raise

    async def _fetch_quotes_for_symbols(
        self,
        symbols: list[str],
        *,
        exchange: str | None = None,
        exchanges: tuple[str, ...] = (),
    ) -> list[MarketQuote]:
        if not symbols:
            return []

        from app.clients.marketstack.stock_mapper import (
            map_eod_quotes_with_change,
            qualify_listing_symbol,
            qualify_listing_symbols,
        )

        qualified = qualify_listing_symbols(symbols, exchange)
        if not qualified:
            return []

        mic_candidates: list[str | None] = []
        if exchange:
            mic_candidates.append(exchange.upper())
        for mic in exchanges:
            upper = mic.upper()
            if upper not in mic_candidates:
                mic_candidates.append(upper)
        mic_candidates.append(None)

        for mic in mic_candidates:
            batch_symbols = [
                qualify_listing_symbol(symbol, mic) for symbol in symbols if symbol.strip()
            ]
            rows = await self._fetch_eod_rows(batch_symbols, exchange=mic)
            quotes = map_eod_quotes_with_change(rows, category="stocks")
            if quotes:
                from app.domain.global_markets.quote_reconcile import (
                    reconcile_quotes_from_eod_rows,
                    should_reconcile_quotes_to_eod,
                )

                if should_reconcile_quotes_to_eod():
                    quotes = reconcile_quotes_from_eod_rows(quotes, rows)
                return [
                    self._with_logo(
                        quote.model_copy(update={"exchange": quote.exchange or mic}),
                    )
                    for quote in quotes
                ]
        return []

    async def get_country_hub(self, country_code: str) -> CountryHubResponse:
        from app.clients.marketstack.stock_mapper import qualify_listing_symbol

        normalized = require_market_country(country_code)
        cache_key = f"country_hub:{normalized}"
        cached = self._country_hub_cache.get(cache_key)
        if cached and cached.sections:
            return cached

        caps = marketstack_capabilities()
        segments = await self._country_exchange_segments(normalized)
        primary_exchange = segments[0][0] if segments else None
        preset = country_hub_preset(normalized)
        is_adr = is_adr_backed_country(normalized)
        # Países via ADR (ex.: Japão) não têm bolsa local na Marketstack —
        # os símbolos do preset são buscados como listagens dos EUA.
        preset_exchange = None if (normalized == "US" or is_adr) else primary_exchange

        market_items: list[MarketQuote] = []
        total_market = 0

        if normalized == "US":
            featured = await self._safe_upstream(self.list_featured_us(), default=None)
            if featured is not None:
                market_items = list(featured.items)[:40]
                total_market = len(market_items)
        elif is_adr:
            market_items = []
            total_market = 0
        elif primary_exchange:
            market_items, pagination = await self._safe_upstream(
                self._fetch_exchange_quotes(
                    primary_exchange,
                    offset=0,
                    limit=40,
                    search=None,
                    category="stocks",
                ),
                default=([], {}),
            )
            total_market = (
                self._pagination_total(pagination)
                if isinstance(pagination, dict)
                else len(market_items)
            ) or len(market_items)

        preset_syms: list[str] = []
        seen: set[str] = set()
        for bucket in (preset.featured, preset.tech, preset.dividends):
            for symbol in bucket:
                upper = symbol.upper().strip()
                if upper and upper not in seen:
                    seen.add(upper)
                    preset_syms.append(upper)

        existing = {quote.symbol.upper() for quote in market_items}
        to_fetch = [
            symbol
            for symbol in preset_syms
            if qualify_listing_symbol(symbol, preset_exchange).upper() not in existing
        ]

        preset_quotes = await self._fetch_quotes_for_symbols(
            to_fetch,
            exchange=preset_exchange,
            exchanges=() if is_adr else tuple(mic for mic, _name in segments),
        )

        by_symbol: dict[str, MarketQuote] = {}
        for quote in market_items:
            by_symbol[quote.symbol.upper()] = quote
        for quote in preset_quotes:
            if is_adr:
                friendly = adr_ticker_name(quote.symbol)
                if friendly:
                    quote = quote.model_copy(update={"name": friendly})
            by_symbol[quote.symbol.upper()] = quote

        all_quotes = list(by_symbol.values())
        if is_adr:
            total_market = len(all_quotes)
        if not all_quotes:
            result = CountryHubResponse(
                country_code=normalized,
                country_name=country_display_name(normalized),
                sections=[],
                total_market=total_market,
                exchange_count=len(segments),
                data_mode=caps.data_mode,
            )
            return result

        def pick(symbols_list: tuple[str, ...]) -> list[MarketQuote]:
            rows: list[MarketQuote] = []
            for symbol in symbols_list:
                qualified = qualify_listing_symbol(symbol, preset_exchange).upper()
                quote = by_symbol.get(qualified) or by_symbol.get(symbol.upper())
                if quote is not None:
                    rows.append(quote)
            return rows

        featured = (pick(preset.featured) or all_quotes[:9])[:9]
        tech = pick(preset.tech)[:6]
        dividends = pick(preset.dividends)[:6]

        sorted_by_change = sorted(all_quotes, key=lambda quote: quote.change_percent, reverse=True)
        gainers = sorted_by_change[:8]
        losers = list(reversed(sorted_by_change[-8:]))[:8]

        sections: list[CountryHubSection] = []
        for section_id, title, items in (
            ("featured", "Principais ativos", featured),
            ("gainers", "Maiores altas", gainers),
            ("tech", "Tecnologia / IA", tech),
            ("dividends", "Dividendos", dividends),
            ("losers", "Maiores quedas", losers),
        ):
            if not items:
                continue
            sections.append(
                CountryHubSection(
                    id=section_id,
                    title=title,
                    items=items,
                    count=len(items),
                )
            )

        result = CountryHubResponse(
            country_code=normalized,
            country_name=country_display_name(normalized),
            sections=sections,
            total_market=total_market,
            exchange_count=len(segments),
            data_mode=caps.data_mode,
        )
        if sections:
            self._country_hub_cache.set(cache_key, result)
        return result

    async def compare_stocks(self, tickers: list[str]) -> StockCompareResponse:
        unique: list[str] = []
        seen: set[str] = set()
        for ticker in tickers:
            normalized = ticker.upper().strip()
            if normalized and normalized not in seen:
                seen.add(normalized)
                unique.append(normalized)

        if not unique:
            return StockCompareResponse(items=[], count=0, provider="marketstack")
        if len(unique) > 3:
            raise UpstreamError("Máximo de 3 tickers por comparação", status_code=400)

        cache_key = f"compare:{','.join(unique)}"
        cached = self._compare_cache.get(cache_key)
        if cached:
            return cached

        items = await asyncio.gather(
            *[self._fetch_compare_item(ticker) for ticker in unique],
        )
        result = StockCompareResponse(items=list(items), count=len(items), provider="marketstack")
        self._compare_cache.set(cache_key, result)
        return result

    async def _fetch_compare_item(self, ticker: str) -> StockCompareItem:
        detail = await self.get_stock_detail(
            ticker,
            candle_limit=280,
            dividend_limit=120,
            split_limit=12,
            include_extras=True,
        )
        profile = to_stock_profile(ticker=detail.ticker, company=detail.company)
        from app.clients.brapi.models import StockCompareReturnPeriod, StockCompareDividendsSnapshot

        next_ev = detail.dividends_summary.next_dividend
        dividends = StockCompareDividendsSnapshot(
            dividend_yield_display=detail.dividends_summary.dividend_yield_ttm,
            dividend_yield_ttm=detail.dividends_summary.dividend_yield_ttm,
            ttm_per_share=detail.dividends_summary.ttm_per_share,
            frequency_label=detail.dividends_summary.frequency_label,
            payments_12m=detail.dividends_summary.payments_12m or None,
            next_com_date=next_ev.com_date if next_ev else None,
            next_payment_date=next_ev.payment_date if next_ev else None,
            next_amount=next_ev.amount if next_ev else None,
            provider="marketstack",
        )
        returns = [
            StockCompareReturnPeriod(label=row.label, return_pct=row.return_pct)
            for row in detail.returns
            if row.return_pct is not None
        ]

        return StockCompareItem(
            quote=detail.quote,
            profile=profile.model_copy(update={"logo_url": detail.quote.logo_url}),
            fundamentals=detail.fundamentals,
            market_stats=detail.market_stats,
            dividends=dividends,
            returns=returns,
            provider="marketstack",
        )

    async def list_world_exchanges(self) -> WorldExchangesResponse:
        cache_key = "world_exchanges:us_br"
        cached = self._exchanges_cache.get(cache_key)
        if cached:
            return cached

        caps = marketstack_capabilities()
        try:
            exchanges = await self._client.map_exchanges()
        except NotConfiguredError:
            exchanges = []
        except UpstreamError:
            exchanges = []

        if not exchanges:
            exchanges = self._fallback_exchanges()

        grouped: dict[str, CountryExchangesGroup] = {}
        for exchange in exchanges:
            code = (exchange.country_code or "XX").upper()
            if not is_market_country_enabled(code):
                continue
            country_name = country_display_name(code, exchange.country or code)
            group = grouped.get(code)
            if group is None:
                group = CountryExchangesGroup(
                    country_code=code,
                    country_name=country_name,
                    exchanges=[],
                )
                grouped[code] = group
            group.exchanges.append(exchange)
            group.exchange_count = len(group.exchanges)

        priority: list[CountryExchangesGroup] = []
        other: list[CountryExchangesGroup] = []
        for code in PRIORITY_COUNTRY_CODES:
            if code in grouped:
                priority.append(grouped.pop(code))
        remaining = sorted(grouped.values(), key=lambda group: group.country_name)
        other.extend(remaining)

        result = WorldExchangesResponse(
            priority_countries=priority,
            other_countries=other,
            total_exchanges=sum(group.exchange_count for group in priority + other),
            total_countries=len(priority) + len(other),
            data_mode=caps.data_mode,
        )
        self._exchanges_cache.set(cache_key, result)
        return result

    @staticmethod
    def _pagination_total(pagination: dict) -> int | None:
        total = pagination.get("total")
        if total is None:
            return None
        try:
            return int(total)
        except (TypeError, ValueError):
            return None

    async def list_exchange_market(
        self,
        mic: str,
        *,
        exchange_name: str | None = None,
        country_code: str | None = None,
        page: int = 1,
        limit: int = 25,
        search: str | None = None,
    ) -> ExchangeMarketListResponse:
        normalized_mic = require_exchange_mic(mic)
        safe_page = max(1, page)
        safe_limit = max(1, min(limit, 50))
        offset = (safe_page - 1) * safe_limit
        search_key = (search or "").strip().lower()
        cache_key = f"exchange_market:v2:{normalized_mic}:{safe_page}:{safe_limit}:{search_key}"
        cached = self._exchange_market_cache.get(cache_key)
        if cached:
            return cached

        caps = marketstack_capabilities()
        pagination: dict = {}

        try:
            if search_key:
                quotes, pagination = await self._fetch_exchange_quotes(
                    normalized_mic,
                    offset=offset,
                    limit=safe_limit,
                    search=search,
                    category="stocks",
                )
            else:
                quotes, pagination = await self._fetch_exchange_quotes(
                    normalized_mic,
                    offset=offset,
                    limit=safe_limit,
                    search=None,
                    category="stocks",
                )
                if not quotes:
                    try:
                        rows, pagination = await self._client.get_exchange_eod(
                            normalized_mic,
                            limit=safe_limit,
                            offset=offset,
                        )
                        from app.clients.marketstack.stock_mapper import map_eod_quotes_with_change

                        quotes = map_eod_quotes_with_change(rows, category="stocks")
                    except UpstreamError:
                        pass

            resolved_name = exchange_name
            if not resolved_name:
                try:
                    info = await self._client.get_exchange(normalized_mic)
                    if info:
                        resolved_name = str(info.get("name") or normalized_mic)
                except (NotConfiguredError, UpstreamError):
                    resolved_name = normalized_mic

            result = ExchangeMarketListResponse(
                exchange_mic=normalized_mic,
                exchange_name=resolved_name,
                country_code=country_code,
                items=quotes,
                count=len(quotes),
                total=self._pagination_total(pagination),
                page=safe_page,
                limit=safe_limit,
                data_mode=caps.data_mode,
            )
            self._exchange_market_cache.set(cache_key, result)
            return result
        except UpstreamError:
            stale = self._exchange_market_cache.get_last_good(cache_key)
            if stale is not None:
                return stale
            raise

    async def _fetch_eod_rows(
        self,
        symbols: list[str],
        *,
        exchange: str | None,
        chunk_size: int = 8,
        lookback_days: int = 12,
    ) -> list[dict]:
        if not symbols:
            return []

        from datetime import UTC, datetime, timedelta

        from app.clients.marketstack.stock_mapper import normalize_marketstack_symbol

        normalized = [normalize_marketstack_symbol(symbol) for symbol in symbols if symbol.strip()]
        if not normalized:
            return []

        def is_exchange_qualified(symbol: str) -> bool:
            if "." not in symbol:
                return False
            suffix = symbol.rsplit(".", 1)[1]
            return not (len(suffix) == 1 and suffix.isalpha())

        suffixed = [symbol for symbol in normalized if is_exchange_qualified(symbol)]
        plain = [symbol for symbol in normalized if symbol not in suffixed]

        # Buscamos uma janela de pregões (não só o último candle) para que a
        # variação seja calculada vs. o fechamento anterior. Cobre fins de
        # semana e feriados longos: no domingo a variação exibida é a de sexta.
        safe_lookback = max(3, min(lookback_days, 30))
        date_from = (datetime.now(UTC).date() - timedelta(days=safe_lookback)).isoformat()
        safe_chunk = max(1, min(chunk_size, 100))

        suffixed_rows = await self._fetch_eod_symbol_chunks(
            suffixed,
            date_from=date_from,
            exchange=None,
            chunk_size=safe_chunk,
        )
        plain_rows = await self._fetch_eod_symbol_chunks(
            plain,
            date_from=date_from,
            exchange=exchange,
            chunk_size=safe_chunk,
        )
        return [*suffixed_rows, *plain_rows]

    async def _fetch_eod_symbol_chunks(
        self,
        symbols: list[str],
        *,
        date_from: str,
        exchange: str | None,
        chunk_size: int,
    ) -> list[dict]:
        if not symbols:
            return []

        chunks = [symbols[start : start + chunk_size] for start in range(0, len(symbols), chunk_size)]

        async def fetch_chunk(chunk: list[str]) -> list[dict]:
            batch = await self._safe_upstream(
                self._client.get_eod_range(
                    chunk,
                    date_from=date_from,
                    exchange=exchange,
                    limit=1000,
                ),
                default=[],
            )
            if not batch and exchange:
                batch = await self._safe_upstream(
                    self._client.get_eod_range(chunk, date_from=date_from, limit=1000),
                    default=[],
                )
            return batch or []

        if len(chunks) == 1:
            return await fetch_chunk(chunks[0])

        batches = await asyncio.gather(*[fetch_chunk(chunk) for chunk in chunks])
        rows: list[dict] = []
        for batch in batches:
            rows.extend(batch)
        return rows

    async def _quotes_from_ticker_rows(
        self,
        rows: list[dict],
        *,
        exchange: str,
        category: str = "stocks",
    ) -> list[MarketQuote]:
        from app.clients.marketstack.stock_mapper import (
            map_eod_quotes_with_change,
            map_ticker_name,
            map_ticker_symbol,
            normalize_marketstack_symbol,
            resolve_catalog_symbol,
            sparklines_from_eod_items,
        )

        symbols: list[str] = []
        names: dict[str, str] = {}
        for row in rows:
            symbol = map_ticker_symbol(row)
            if not symbol:
                continue
            symbols.append(symbol)
            names[symbol] = map_ticker_name(row, symbol=symbol)

        if not symbols:
            return []

        resolved_exchange = None
        sample = normalize_marketstack_symbol(symbols[0])
        if "." in sample:
            suffix = sample.rsplit(".", 1)[1]
            if not (len(suffix) == 1 and suffix.isalpha()):
                resolved_exchange = None
            else:
                resolved_exchange = exchange
        else:
            resolved_exchange = exchange

        eod_rows = await self._fetch_eod_rows(
            symbols,
            exchange=resolved_exchange,
            chunk_size=max(len(symbols), 8),
            lookback_days=90,
        )
        spark_map = sparklines_from_eod_items(eod_rows)
        mapped = map_eod_quotes_with_change(eod_rows, category=category)
        quotes: list[MarketQuote] = []
        for quote in mapped:
            catalog_symbol = resolve_catalog_symbol(quote.symbol, symbols)
            quote = quote.model_copy(
                update={
                    "symbol": catalog_symbol,
                    "name": names.get(catalog_symbol, quote.name),
                    "exchange": quote.exchange or exchange,
                    "sparkline": GlobalMarketService._sparkline_for_quote(
                        quote.model_copy(update={"symbol": catalog_symbol}),
                        spark_map,
                    ),
                }
            )
            quotes.append(self._with_logo(quote))
        return await self._finalize_batch_quotes(quotes, eod_rows=eod_rows, exchange=exchange)

    @staticmethod
    def _sparkline_for_quote(
        quote: MarketQuote,
        spark_map: dict[str, list[float]],
    ) -> list[float]:
        from app.clients.marketstack.stock_mapper import normalize_marketstack_symbol

        spark = (
            spark_map.get(quote.symbol)
            or spark_map.get(quote.symbol.upper())
            or spark_map.get(normalize_marketstack_symbol(quote.symbol), [])
        )
        return spark if len(spark) >= 2 else []

    @staticmethod
    def _fallback_exchanges():
        from app.domain.global_markets.models import ExchangeInfo
        from app.domain.global_markets.presets import BR_EXCHANGES, COUNTRY_EXCHANGE_FALLBACK

        fallback = []
        for item in [*US_EXCHANGES, *BR_EXCHANGES]:
            fallback.append(
                ExchangeInfo(
                    mic=item["mic"],
                    name=item["name"],
                    country=item["country_name"],
                    country_code=item["country_code"],
                )
            )
        for code, segments in COUNTRY_EXCHANGE_FALLBACK.items():
            country_name = country_display_name(code)
            for mic, name in segments:
                fallback.append(
                    ExchangeInfo(
                        mic=mic,
                        name=name,
                        country=country_name,
                        country_code=code,
                    )
                )
        return fallback


global_market_service = GlobalMarketService()
