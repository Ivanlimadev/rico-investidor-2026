from __future__ import annotations

import asyncio

from app.clients.bolsai.client import BolsaiClient
from app.clients.bolsai.models import BolsaiDividendsResponse
from app.clients.bolsai.corporate_mapper import map_bolsai_corporate_actions
from app.clients.bolsai.proventos_mapper import (
    map_bolsai_fii_distributions,
    map_bolsai_stock_dividends,
)
from app.clients.brapi.client import BrapiClient
from app.clients.brapi.models import (
    MarketQuote,
    StockDividendEvent,
    StockDividendsResponse,
    StockDividendsSummary,
    StockFundamentals,
)
from app.config import settings
from app.core.cache import TtlCache
from app.core.exceptions import UpstreamError
from app.domain.dividends.br_dividend_analytics import (
    build_br_dividends_summary,
    resolve_display_dividend_yield,
)
from app.domain.fii.models import FiiDetail, FiiDistributions
from app.domain.fii.ticker import is_valid_fii_ticker, normalize_fii_ticker
from app.domain.quotes.br_quote_reconcile import merge_bolsai_fundamentals_into_quote
from app.domain.quotes.category_map import looks_like_fii


def _dy_from_fundamentals_payload(payload: dict) -> float | None:
    for key in ("dividend_yield", "dividend_yield_ttm", "dy"):
        raw = payload.get(key)
        if raw is None:
            continue
        try:
            return round(float(raw), 2)
        except (TypeError, ValueError):
            continue
    return None


class BrProventosService:
    """Proventos e métricas de dividendos B3 — Bolsai (primário) com fallback Brapi."""

    def __init__(
        self,
        *,
        bolsai: BolsaiClient | None = None,
        brapi: BrapiClient | None = None,
    ) -> None:
        self._bolsai = bolsai or BolsaiClient()
        self._brapi = brapi or BrapiClient()
        cache_ttl = settings.bolsai_ticker_cache_ttl_seconds
        self._fundamentals_cache: TtlCache[dict] = TtlCache(cache_ttl)
        self._dividends_cache: TtlCache[BolsaiDividendsResponse] = TtlCache(cache_ttl)
        self._company_cache: TtlCache[dict] = TtlCache(cache_ttl)
        self._bolsai_quote_cache: TtlCache[dict] = TtlCache(cache_ttl)

    @property
    def uses_bolsai(self) -> bool:
        return self._bolsai.configured

    async def _enrich_stock_dividends_metadata(
        self,
        ticker: str,
        dividends: StockDividendsResponse,
    ) -> StockDividendsResponse:
        if dividends.dividend_yield_ttm is not None:
            return dividends
        dy = await self.fetch_dividend_yield_ttm(ticker)
        if dy is None:
            return dividends
        return dividends.model_copy(update={"dividend_yield_ttm": dy})

    async def get_company_cached(self, ticker: str) -> dict | None:
        normalized = ticker.upper().strip()
        if not normalized or not self._bolsai.configured:
            return None
        cached = self._company_cache.get(normalized)
        if cached is not None:
            return cached
        payload = await self._bolsai.get_company(normalized)
        if payload:
            self._company_cache.set(normalized, payload)
        return payload

    async def fetch_company_names_batch(
        self,
        tickers: list[str],
        *,
        max_concurrency: int | None = None,
    ) -> dict[str, str]:
        if not self._bolsai.configured:
            return {}
        from app.clients.bolsai.companies_mapper import company_display_name

        unique = list(dict.fromkeys(t.upper().strip() for t in tickers if t and t.strip()))
        if not unique:
            return {}

        concurrency = max_concurrency or settings.bolsai_dy_enrich_concurrency
        semaphore = asyncio.Semaphore(max(1, concurrency))
        names: dict[str, str] = {}

        async def one(symbol: str) -> None:
            try:
                async with semaphore:
                    payload = await self.get_company_cached(symbol)
                    display = company_display_name(payload)
                    if display:
                        names[symbol] = display
            except Exception:
                return

        await asyncio.gather(*(one(symbol) for symbol in unique))
        return names

    async def get_bolsai_quote_cached(self, ticker: str) -> dict | None:
        normalized = ticker.upper().strip()
        if not normalized or not self._bolsai.configured:
            return None
        cached = self._bolsai_quote_cache.get(normalized)
        if cached is not None:
            return cached
        payload = await self._bolsai.get_stock_quote(normalized)
        if payload:
            self._bolsai_quote_cache.set(normalized, payload)
        return payload

    async def display_dividend_yield_for_price(
        self,
        ticker: str,
        *,
        price: float,
        limit: int = 60,
    ) -> float | None:
        """DY exibido — janela de pagamentos estilo Investidor10."""
        if price <= 0:
            return None
        dividends = await self.get_stock_dividends(ticker, limit=limit)
        enriched = self.enrich_dividends_with_summary(dividends, price=price)
        return resolve_display_dividend_yield(
            dividend_yield_display=enriched.summary.dividend_yield_display,
            dividend_yield_ttm=enriched.dividend_yield_ttm,
        )

    async def reconcile_market_quote(self, quote: MarketQuote) -> MarketQuote:
        """Cotação + DY + fundamentos alinhados (Bolsai + regra Investidor10)."""
        price = quote.price
        display_dy = await self.display_dividend_yield_for_price(
            quote.symbol,
            price=price,
        )

        if not self._bolsai.configured:
            if display_dy is None:
                return quote
            return quote.model_copy(update={"dividend_yield_12m": display_dy})

        fund_raw, quote_raw = await asyncio.gather(
            self.get_fundamentals_cached(quote.symbol),
            self.get_bolsai_quote_cached(quote.symbol),
            return_exceptions=True,
        )
        fund_payload = fund_raw if isinstance(fund_raw, dict) else None
        quote_payload = quote_raw if isinstance(quote_raw, dict) else None

        reconciled_price = price
        quote_patch = merge_bolsai_fundamentals_into_quote(
            quote,
            fundamentals=fund_payload,
            bolsai_quote=quote_payload,
            display_dividend_yield=None,
        )
        if quote_patch.price > 0:
            reconciled_price = quote_patch.price

        if reconciled_price != price:
            display_dy = await self.display_dividend_yield_for_price(
                quote.symbol,
                price=reconciled_price,
            )

        return merge_bolsai_fundamentals_into_quote(
            quote,
            fundamentals=fund_payload,
            bolsai_quote=quote_payload,
            display_dividend_yield=display_dy,
        )

    async def reconcile_market_quotes_batch(
        self,
        items: list[MarketQuote],
        *,
        max_concurrency: int | None = None,
    ) -> list[MarketQuote]:
        if not items:
            return items

        concurrency = max_concurrency or settings.bolsai_dy_enrich_concurrency
        semaphore = asyncio.Semaphore(max(1, concurrency))

        async def one(item: MarketQuote) -> MarketQuote:
            try:
                async with semaphore:
                    return await self.reconcile_market_quote(item)
            except Exception:
                return item

        return list(await asyncio.gather(*(one(item) for item in items)))

    async def get_fundamentals_cached(self, ticker: str) -> dict | None:
        normalized = ticker.upper().strip()
        if not normalized:
            return None
        cached = self._fundamentals_cache.get(normalized)
        if cached is not None:
            return cached
        payload = await self._bolsai.get_fundamentals(normalized)
        if payload:
            self._fundamentals_cache.set(normalized, payload)
        return payload

    async def _bolsai_dividends_cached(self, ticker: str) -> BolsaiDividendsResponse | None:
        normalized = ticker.upper().strip()
        if not normalized:
            return None
        cached = self._dividends_cache.get(normalized)
        if cached is not None:
            return cached
        payload = await self._bolsai.get_dividends(normalized)
        if payload is not None:
            self._dividends_cache.set(normalized, payload)
        return payload

    async def get_stock_dividends(self, ticker: str, *, limit: int = 120) -> StockDividendsResponse:
        normalized = ticker.upper().strip()
        if self._bolsai.configured:
            payload = await self._bolsai_dividends_cached(normalized)
            if payload is not None:
                result = map_bolsai_stock_dividends(payload, limit=limit)
                company = await self.get_company_cached(normalized)
                if company:
                    from app.clients.bolsai.companies_mapper import company_display_name

                    display_name = company_display_name(company)
                    if display_name:
                        result = result.model_copy(update={"name": display_name})
                result = await self._enrich_stock_dividends_metadata(normalized, result)
                if result.dividend_yield_ttm is None:
                    dy = await self.fetch_dividend_yield_ttm(normalized)
                    if dy is not None:
                        result = result.model_copy(update={"dividend_yield_ttm": dy})
                corporate = await self._corporate_actions_hybrid(normalized)
                if corporate:
                    return result.model_copy(update={"corporate_actions": corporate})
                return result

        return await self._brapi.get_stock_dividends(normalized, limit=limit)

    async def get_fii_distributions(
        self,
        ticker: str,
        *,
        years: int = 5,
        name: str | None = None,
        close_price: float | None = None,
        dividend_yield_ttm: float | None = None,
    ) -> FiiDistributions:
        normalized = normalize_fii_ticker(ticker)
        if self._bolsai.configured:
            payload = await self._bolsai.get_fii_distributions(normalized)
            if payload is not None:
                return map_bolsai_fii_distributions(
                    payload,
                    years=years,
                    name=name,
                    close_price=close_price,
                    dividend_yield_ttm=dividend_yield_ttm,
                )

        return await self._brapi.get_fii_distributions(
            normalized,
            years=years,
            name=name,
            close_price=close_price,
            dividend_yield_ttm=dividend_yield_ttm,
        )

    async def enrich_fii_detail(self, detail: FiiDetail) -> FiiDetail:
        if not self._bolsai.configured:
            return detail

        payload = await self._bolsai.get_fii_distributions(detail.ticker)
        if payload is None:
            return detail

        updates: dict[str, object] = {}
        if payload.dividend_yield_ttm is not None:
            updates["dividend_yield_ttm"] = payload.dividend_yield_ttm
        if payload.close_price is not None:
            updates["close_price"] = payload.close_price
        if not updates:
            return detail
        return detail.model_copy(update=updates)

    @staticmethod
    def enrich_dividends_with_summary(
        dividends: StockDividendsResponse,
        *,
        price: float | None,
    ) -> StockDividendsResponse:
        if price is None or price <= 0:
            return dividends
        try:
            payload = build_br_dividends_summary(
                dividends.payments,
                dividends.annual_summary,
                price=float(price),
            )
        except Exception:
            return dividends
        summary = StockDividendsSummary(
            dividend_yield_display=payload.get("dividend_yield_display"),
            ttm_per_share_display=payload.get("ttm_per_share_display"),
            dividend_yield_avg_5y=payload.get("dividend_yield_avg_5y"),
            dividend_yield_avg_10y=payload.get("dividend_yield_avg_10y"),
            frequency_label=payload.get("frequency_label"),
            avg_amount_12m=payload.get("avg_amount_12m"),
            payments_12m=payload.get("payments_12m"),
            next_dividend=_event_from_payload(payload.get("next_dividend")),
            upcoming=[
                event
                for raw in payload.get("upcoming") or []
                if (event := _event_from_payload(raw)) is not None
            ],
        )
        return dividends.model_copy(update={"summary": summary})

    @staticmethod
    def merge_dividend_yield_into_fundamentals(
        fundamentals: StockFundamentals,
        dividends: StockDividendsResponse,
    ) -> StockFundamentals:
        dy = resolve_display_dividend_yield(
            dividend_yield_display=dividends.summary.dividend_yield_display,
            dividend_yield_ttm=dividends.dividend_yield_ttm,
        )
        if dy is None:
            return fundamentals
        return fundamentals.model_copy(update={"dividend_yield_12m": dy})


    async def fetch_dividend_yield_ttm(
        self,
        ticker: str,
        *,
        price: float | None = None,
    ) -> float | None:
        normalized = ticker.upper().strip()
        if not normalized:
            return None

        if price is not None and price > 0:
            computed = await self.display_dividend_yield_for_price(
                normalized,
                price=price,
            )
            if computed is not None:
                return computed

        try:
            if self._bolsai.configured:
                payload = await self._bolsai.get_dividends(normalized)
                if payload is not None and payload.dividend_yield_ttm is not None:
                    return payload.dividend_yield_ttm
                fundamentals = await self.get_fundamentals_cached(normalized)
                if fundamentals:
                    dy = _dy_from_fundamentals_payload(fundamentals)
                    if dy is not None:
                        return dy

            brapi_div = await self._brapi.get_stock_dividends(normalized, limit=1)
            return brapi_div.dividend_yield_ttm
        except (UpstreamError, Exception):
            return None

    async def fetch_dividend_yields_batch(
        self,
        tickers: list[str],
        *,
        max_concurrency: int | None = None,
        max_symbols: int | None = None,
    ) -> dict[str, float]:
        fundamentals = await self.fetch_fundamentals_batch(
            tickers,
            max_concurrency=max_concurrency,
            max_symbols=max_symbols,
        )
        results: dict[str, float] = {}
        for symbol, payload in fundamentals.items():
            dy = _dy_from_fundamentals_payload(payload)
            if dy is not None:
                results[symbol] = dy
        return results

    async def fetch_fundamentals_batch(
        self,
        tickers: list[str],
        *,
        max_concurrency: int | None = None,
        max_symbols: int | None = None,
    ) -> dict[str, dict]:
        if not self._bolsai.configured:
            return {}

        unique = list(dict.fromkeys(t.upper().strip() for t in tickers if t and t.strip()))
        if not unique:
            return {}

        cap = max_symbols if max_symbols is not None else settings.bolsai_dy_list_max_symbols
        if cap > 0:
            unique = unique[: max(1, cap)]

        concurrency = max_concurrency or settings.bolsai_dy_enrich_concurrency
        semaphore = asyncio.Semaphore(max(1, concurrency))
        results: dict[str, dict] = {}

        async def one(symbol: str) -> None:
            try:
                async with semaphore:
                    payload = await self.get_fundamentals_cached(symbol)
                    if payload:
                        results[symbol] = payload
            except Exception:
                return

        await asyncio.gather(*(one(symbol) for symbol in unique))
        return results

    async def _corporate_actions_hybrid(self, ticker: str) -> list:
        if self._bolsai.configured:
            try:
                payload = await self._bolsai.get_corporate_events(ticker)
                if isinstance(payload, dict):
                    actions = map_bolsai_corporate_actions(payload)
                    if actions:
                        return actions
            except Exception:
                pass
        return await self._corporate_actions_from_brapi(ticker)

    async def _corporate_actions_from_brapi(self, ticker: str) -> list:
        try:
            brapi_result = await self._brapi.get_stock_dividends(ticker, limit=1)
        except Exception:
            return []
        return list(brapi_result.corporate_actions or [])

    def is_fii_ticker(self, ticker: str) -> bool:
        normalized = ticker.upper().strip()
        return is_valid_fii_ticker(normalized) and looks_like_fii(normalize_fii_ticker(normalized))


def _event_from_payload(raw: object) -> StockDividendEvent | None:
    if not isinstance(raw, dict):
        return None
    return StockDividendEvent(
        label=raw.get("label"),
        com_date=raw.get("com_date"),
        ex_date=raw.get("ex_date"),
        payment_date=raw.get("payment_date"),
        value_per_share=raw.get("value_per_share"),
        is_projected=bool(raw.get("is_projected")),
    )


br_proventos_service = BrProventosService()
