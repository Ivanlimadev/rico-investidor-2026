from __future__ import annotations

from app.clients.brapi.models import MarketQuote
from app.clients.marketstack.client import MarketstackClient
from app.clients.marketstack.stock_mapper import map_eod_quotes_with_change
from app.core.exceptions import UpstreamError
from app.domain.crypto.presets import CRYPTO_NAMES
from app.domain.related_assets.models import RelatedAssetItem, RelatedAssetsResponse
from app.domain.related_assets.resolver import normalize_ticker, resolve_peer_candidates
from app.services.crypto_service import crypto_service
from app.services.global_market_service import global_market_service
from app.services.quote_service import quote_service


class RelatedAssetsService:
    async def list_related(
        self,
        ticker: str,
        *,
        market: str,
        sector: str | None = None,
        industry: str | None = None,
        limit: int = 6,
    ) -> RelatedAssetsResponse:
        normalized = normalize_ticker(ticker)
        safe_limit = max(1, min(limit, 8))
        group_label, candidates = resolve_peer_candidates(
            normalized,
            market=market,
            sector=sector,
            industry=industry,
            limit=safe_limit,
        )

        if not candidates:
            return RelatedAssetsResponse(
                ticker=normalized,
                group_label=group_label,
                items=[],
                count=0,
                market=market,
            )

        symbols = [symbol for symbol, _ in candidates]
        reason_by_symbol = {symbol: reason for symbol, reason in candidates}
        market_slug = market.strip().lower()

        if market_slug == "cripto":
            items = await self._fetch_crypto(symbols, reason_by_symbol, category="cripto")
        elif market_slug in {"stocks", "reits"}:
            category = "reits" if market_slug == "reits" else "stocks"
            items = await self._fetch_us(symbols, reason_by_symbol, category=category)
        else:
            items = await self._fetch_br(symbols, reason_by_symbol, market=market_slug)

        return RelatedAssetsResponse(
            ticker=normalized,
            group_label=group_label,
            items=items[:safe_limit],
            count=min(len(items), safe_limit),
            market=market,
        )

    async def _fetch_br(
        self,
        symbols: list[str],
        reason_by_symbol: dict[str, str],
        *,
        market: str,
    ) -> list[RelatedAssetItem]:
        try:
            batch = await quote_service.get_quotes_batch(symbols)
        except UpstreamError:
            return []

        category = market if market in {"acoes_br", "bdr", "etf", "etf_br", "fiis"} else "acoes_br"
        items: list[RelatedAssetItem] = []
        for quote in batch.items:
            items.append(_quote_to_related(quote, reason_by_symbol.get(quote.symbol, ""), category=category))
        return _order_by_symbols(symbols, items)

    async def _fetch_us(
        self,
        symbols: list[str],
        reason_by_symbol: dict[str, str],
        *,
        category: str,
    ) -> list[RelatedAssetItem]:
        client = MarketstackClient()
        if not client.configured:
            return []

        try:
            rows = await client.get_eod_latest(symbols)
            quotes = map_eod_quotes_with_change(rows, category=category)
        except UpstreamError:
            return []

        items: list[RelatedAssetItem] = []
        for quote in quotes:
            enriched = global_market_service._with_logo(quote)
            items.append(
                RelatedAssetItem(
                    symbol=enriched.symbol,
                    name=enriched.name,
                    price=enriched.price,
                    change_percent=enriched.change_percent,
                    category=category,
                    reason=reason_by_symbol.get(enriched.symbol, ""),
                    logo_url=enriched.logo_url,
                    exchange_mic=enriched.exchange,
                    provider="marketstack",
                )
            )
        return _order_by_symbols(symbols, items)

    async def _fetch_crypto(
        self,
        symbols: list[str],
        reason_by_symbol: dict[str, str],
        *,
        category: str,
    ) -> list[RelatedAssetItem]:
        try:
            rates = await crypto_service.get_rates_for_symbols(symbols)
        except UpstreamError:
            return []

        by_symbol = {item.symbol: item for item in rates.items}
        items: list[RelatedAssetItem] = []
        for symbol in symbols:
            quote = by_symbol.get(symbol)
            if quote is None:
                continue
            items.append(
                RelatedAssetItem(
                    symbol=quote.symbol,
                    name=quote.name or CRYPTO_NAMES.get(symbol, symbol),
                    price=quote.price,
                    change_percent=quote.change_percent,
                    category=category,
                    reason=reason_by_symbol.get(symbol, ""),
                    logo_url=quote.image_url,
                    provider="binance",
                )
            )
        return items


def _quote_to_related(quote: MarketQuote, reason: str, *, category: str) -> RelatedAssetItem:
    return RelatedAssetItem(
        symbol=quote.symbol,
        name=quote.name,
        price=quote.price,
        change_percent=quote.change_percent,
        category=category,
        reason=reason,
        logo_url=quote.logo_url,
        exchange_mic=quote.exchange,
        provider=quote.provider or "brapi",
    )


def _order_by_symbols(symbols: list[str], items: list[RelatedAssetItem]) -> list[RelatedAssetItem]:
    by_symbol = {item.symbol: item for item in items}
    return [by_symbol[s] for s in symbols if s in by_symbol]


related_assets_service = RelatedAssetsService()
