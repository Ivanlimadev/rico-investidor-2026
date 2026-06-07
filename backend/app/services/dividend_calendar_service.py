from __future__ import annotations

import asyncio

from app.clients.marketstack.client import MarketstackClient
from app.config import settings
from app.clients.marketstack.stock_mapper import map_dividends
from app.core.cache import StaleTtlCache
from app.domain.dividends.calendar_builder import (
    filter_upcoming_entries,
    sort_calendar_entries,
)
from app.domain.dividends.calendar_models import DividendCalendarEntry, DividendCalendarResponse
from app.domain.dividends.calendar_universe import (
    US_DIVIDEND_CALENDAR_TICKERS,
    us_company_name,
)
from app.domain.global_markets.us_dividend_dates import investidor10_com_date

_US_SNAPSHOT_TTL = 60 * 45


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
        marketstack: MarketstackClient | None = None,
    ) -> None:
        self._marketstack = marketstack or MarketstackClient()
        self._us_cache: StaleTtlCache[tuple[DividendCalendarEntry, ...]] = StaleTtlCache(
            _US_SNAPSHOT_TTL,
        )
        self._us_rebuild_lock = asyncio.Lock()
        self._us_rebuild_task: asyncio.Task[None] | None = None

    async def get_calendar(
        self,
        *,
        market: str,
        sort_by: str = "payment",
        days_ahead: int = 120,
    ) -> DividendCalendarResponse:
        normalized_market = market.strip().lower()
        if normalized_market != "us":
            normalized_market = "us"

        safe_days = max(7, min(days_ahead, 365))

        raw_entries, data_sources = await self._resolve_us_snapshot()

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
