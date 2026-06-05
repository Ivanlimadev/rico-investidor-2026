from __future__ import annotations

import asyncio
from dataclasses import dataclass
from datetime import date

from app.clients.bolsai.dividend_mapper import (
    calendar_entries_from_fii_distributions,
    calendar_entries_from_stock_dividends,
)
from app.domain.fii.ticker import is_valid_fii_ticker, normalize_fii_ticker
from app.domain.quotes.category_map import looks_like_fii
from app.clients.brapi.client import BrapiClient
from app.clients.brapi.stock_mapper import map_stock_dividends
from app.clients.marketstack.client import MarketstackClient
from app.config import settings
from app.clients.marketstack.stock_mapper import map_dividends
from app.core.cache import StaleTtlCache
from app.domain.dividends.calendar_builder import (
    filter_upcoming_entries,
    sort_calendar_entries,
)
from app.domain.dividends.calendar_merge import merge_br_dividend_entries
from app.domain.dividends.calendar_models import DividendCalendarEntry, DividendCalendarResponse
from app.domain.dividends.calendar_loader import load_br_dividend_calendar_tickers
from app.domain.dividends.calendar_universe import (
    US_DIVIDEND_CALENDAR_TICKERS,
    us_company_name,
)
from app.domain.global_markets.us_dividend_dates import investidor10_com_date
from app.services.br_proventos_service import BrProventosService, br_proventos_service

_SNAPSHOT_TTL = 60 * 60 * 6
_US_SNAPSHOT_TTL = 60 * 45


@dataclass(frozen=True)
class _BrCalendarSnapshot:
    entries: tuple[DividendCalendarEntry, ...]
    data_sources: tuple[str, ...]


def _normalize_label(value: str | None) -> str:
    if not value or not value.strip():
        return "Dividendo"
    return value.strip().title()


def _br_entries_from_quote(item: dict) -> list[DividendCalendarEntry]:
    symbol = str(item.get("symbol") or "").upper().strip()
    if not symbol:
        return []

    name = str(item.get("longName") or item.get("shortName") or symbol).strip()
    dividends = map_stock_dividends(
        ticker=symbol,
        dividends_data=item.get("dividendsData"),
        limit=250,
    )
    return calendar_entries_from_stock_dividends(dividends, company_name=name)


def _us_entries_from_dividends(symbol: str, items: list) -> list[DividendCalendarEntry]:
    name = us_company_name(symbol)
    rows: list[DividendCalendarEntry] = []
    for item in items:
        ex = item.ex_date or item.date
        if not ex or item.amount is None:
            continue
        com = item.com_date or investidor10_com_date(ex) or ex
        rows.append(
            DividendCalendarEntry(
                market="us",
                symbol=symbol,
                company_name=name,
                exchange="NYSE/NASDAQ",
                dividend_type="Dividendos",
                com_date=com,
                payment_date=item.payment_date,
                amount=round(float(item.amount), 4),
                currency="USD",
            )
        )
    return rows


class DividendCalendarService:
    def __init__(
        self,
        *,
        brapi: BrapiClient | None = None,
        proventos: BrProventosService | None = None,
        marketstack: MarketstackClient | None = None,
    ) -> None:
        self._brapi = brapi or BrapiClient()
        self._proventos = proventos or br_proventos_service
        self._marketstack = marketstack or MarketstackClient()
        self._br_snapshot_cache: StaleTtlCache[_BrCalendarSnapshot] = StaleTtlCache(_SNAPSHOT_TTL)
        self._us_cache: StaleTtlCache[tuple[DividendCalendarEntry, ...]] = StaleTtlCache(
            _US_SNAPSHOT_TTL,
        )
        self._br_rebuild_lock = asyncio.Lock()
        self._us_rebuild_lock = asyncio.Lock()
        self._br_rebuild_task: asyncio.Task[None] | None = None
        self._us_rebuild_task: asyncio.Task[None] | None = None

    def _br_snapshot_key(self) -> str:
        source_tag = "bolsai" if self._proventos.uses_bolsai else "brapi"
        return f"divcal_snapshot:br:{source_tag}"

    async def warm_br_snapshot(self) -> None:
        """Pré-aquece a agenda BR em background (lifespan / primeiro cold start)."""
        await self._rebuild_br_snapshot()

    async def get_calendar(
        self,
        *,
        market: str,
        sort_by: str = "payment",
        days_ahead: int = 120,
    ) -> DividendCalendarResponse:
        normalized_market = market.strip().lower()
        if normalized_market not in {"br", "us"}:
            normalized_market = "br"

        safe_days = max(7, min(days_ahead, 365))

        if normalized_market == "us":
            raw_entries, data_sources = await self._resolve_us_snapshot()
        else:
            raw_entries, data_sources = await self._resolve_br_snapshot()

        filtered = filter_upcoming_entries(raw_entries, days_ahead=safe_days)
        sorted_items = sort_calendar_entries(filtered, sort_by=sort_by)

        return DividendCalendarResponse(
            market=normalized_market,
            sort_by=sort_by if sort_by in {"com", "payment"} else "payment",
            days_ahead=safe_days,
            count=len(sorted_items),
            items=sorted_items,
            data_sources=list(data_sources),
        )

    async def _resolve_br_snapshot(self) -> tuple[list[DividendCalendarEntry], list[str]]:
        cache_key = self._br_snapshot_key()
        fresh = self._br_snapshot_cache.get(cache_key)
        if fresh is not None:
            return list(fresh.entries), list(fresh.data_sources)

        stale = self._br_snapshot_cache.get_last_good(cache_key)
        if stale is not None:
            self._schedule_br_rebuild()
            return list(stale.entries), list(stale.data_sources)

        return await self._rebuild_br_snapshot()

    def _schedule_br_rebuild(self) -> None:
        if self._br_rebuild_task is not None and not self._br_rebuild_task.done():
            return
        try:
            loop = asyncio.get_running_loop()
        except RuntimeError:
            return
        self._br_rebuild_task = loop.create_task(self._rebuild_br_snapshot())

    async def _rebuild_br_snapshot(self) -> tuple[list[DividendCalendarEntry], list[str]]:
        async with self._br_rebuild_lock:
            cache_key = self._br_snapshot_key()
            fresh = self._br_snapshot_cache.get(cache_key)
            if fresh is not None:
                return list(fresh.entries), list(fresh.data_sources)

            entries, sources = await self._load_br_entries()
            snapshot = _BrCalendarSnapshot(
                entries=tuple(entries),
                data_sources=tuple(sources),
            )
            self._br_snapshot_cache.set(cache_key, snapshot)
            return entries, sources

    async def _resolve_us_snapshot(self) -> tuple[list[DividendCalendarEntry], list[str]]:
        cache_key = "divcal_snapshot:us"
        fresh = self._us_cache.get(cache_key)
        if fresh is not None:
            return list(fresh), ["marketstack"] if settings.marketstack_api_key.strip() else []

        stale = self._us_cache.get_last_good(cache_key)
        if stale is not None:
            self._schedule_us_rebuild()
            return list(stale), ["marketstack"] if settings.marketstack_api_key.strip() else []

        entries = await self._rebuild_us_snapshot()
        return entries, ["marketstack"] if settings.marketstack_api_key.strip() else []

    def _schedule_us_rebuild(self) -> None:
        if self._us_rebuild_task is not None and not self._us_rebuild_task.done():
            return
        try:
            loop = asyncio.get_running_loop()
        except RuntimeError:
            return
        self._us_rebuild_task = loop.create_task(self._rebuild_us_snapshot())

    async def _rebuild_us_snapshot(self) -> list[DividendCalendarEntry]:
        async with self._us_rebuild_lock:
            cache_key = "divcal_snapshot:us"
            fresh = self._us_cache.get(cache_key)
            if fresh is not None:
                return list(fresh)

            entries = await self._load_us_entries()
            self._us_cache.set(cache_key, tuple(entries))
            return entries

    async def _load_br_company_names(self, tickers: list[str]) -> dict[str, str]:
        names: dict[str, str] = {}
        if self._proventos.uses_bolsai:
            names.update(
                await self._proventos.fetch_company_names_batch(
                    tickers,
                    max_concurrency=settings.bolsai_dy_enrich_concurrency,
                )
            )
        missing = [ticker for ticker in tickers if ticker.upper() not in names]
        if not missing:
            return names

        batch_size = BrapiClient.MAX_BATCH
        for offset in range(0, len(missing), batch_size):
            batch = missing[offset : offset + batch_size]
            try:
                quotes = await self._brapi.get_quotes_raw(batch)
            except Exception:
                continue
            for item in quotes:
                symbol = str(item.get("symbol") or "").upper().strip()
                if not symbol:
                    continue
                name = str(item.get("longName") or item.get("shortName") or symbol).strip()
                if name.upper() == symbol:
                    name = symbol
                names[symbol] = name
        return names

    async def _load_br_proventos_entries(
        self,
        tickers: list[str],
        names: dict[str, str],
    ) -> list[DividendCalendarEntry]:
        concurrency = (
            settings.bolsai_dy_enrich_concurrency
            if self._proventos.uses_bolsai
            else 8
        )
        semaphore = asyncio.Semaphore(max(4, concurrency))

        async def fetch_one(symbol: str) -> list[DividendCalendarEntry]:
            async with semaphore:
                normalized = symbol.upper().strip()
                try:
                    if is_valid_fii_ticker(normalized) and looks_like_fii(
                        normalize_fii_ticker(normalized)
                    ):
                        distributions = await self._proventos.get_fii_distributions(
                            normalized,
                            years=5,
                            name=names.get(normalized),
                        )
                        return calendar_entries_from_fii_distributions(distributions)

                    dividends = await self._proventos.get_stock_dividends(normalized, limit=250)
                except Exception:
                    return []
                return calendar_entries_from_stock_dividends(
                    dividends,
                    company_name=dividends.name or names.get(normalized, normalized),
                )

        batches = await asyncio.gather(*(fetch_one(symbol) for symbol in tickers))
        rows: list[DividendCalendarEntry] = []
        for batch in batches:
            rows.extend(batch)
        return rows

    async def _load_brapi_dividend_entries(self, tickers: list[str]) -> list[DividendCalendarEntry]:
        if self._proventos.uses_bolsai:
            return []

        rows: list[DividendCalendarEntry] = []
        batch_size = BrapiClient.MAX_BATCH
        for offset in range(0, len(tickers), batch_size):
            batch = tickers[offset : offset + batch_size]
            try:
                quotes = await self._brapi.get_quotes_with_dividends(batch)
            except Exception:
                continue
            for item in quotes:
                rows.extend(_br_entries_from_quote(item))
        return rows

    async def _load_br_entries(self) -> tuple[list[DividendCalendarEntry], list[str]]:
        tickers = list(await load_br_dividend_calendar_tickers())
        sources: list[str] = []

        names = await self._load_br_company_names(tickers)
        if names:
            if self._proventos.uses_bolsai:
                sources.append("bolsai")
            else:
                sources.append("brapi")

        primary_rows = await self._load_br_proventos_entries(tickers, names)
        if primary_rows and self._proventos.uses_bolsai:
            sources.insert(0, "bolsai")

        fallback_rows = await self._load_brapi_dividend_entries(tickers)
        if fallback_rows:
            if "brapi" not in sources:
                sources.append("brapi")
            if self._proventos.uses_bolsai:
                return merge_br_dividend_entries(bolsai=primary_rows, brapi=fallback_rows), sources
            return fallback_rows, sources

        return primary_rows, sources or (["bolsai"] if self._proventos.uses_bolsai else ["brapi"])

    async def _load_us_entries(self) -> list[DividendCalendarEntry]:
        if not settings.marketstack_api_key.strip():
            return []

        semaphore = asyncio.Semaphore(4)
        tickers = list(US_DIVIDEND_CALENDAR_TICKERS)

        async def fetch_one(symbol: str) -> list[DividendCalendarEntry]:
            async with semaphore:
                try:
                    payload, _ = await self._marketstack.get_ticker_dividends(symbol, limit=40)
                    mapped = map_dividends(payload)
                    return _us_entries_from_dividends(symbol, mapped)
                except Exception:
                    return []

        batches = await asyncio.gather(*(fetch_one(symbol) for symbol in tickers))
        rows: list[DividendCalendarEntry] = []
        for batch in batches:
            rows.extend(batch)
        return rows


dividend_calendar_service = DividendCalendarService()
