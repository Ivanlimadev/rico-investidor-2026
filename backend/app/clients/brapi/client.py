import asyncio

import httpx

from app.clients.brapi.fii_mapper import (
    map_candles,
    map_distributions,
    map_history,
    merge_fii_detail,
    pct_from_ratio,
)
from app.clients.brapi.models import (
    MarketQuote,
    StockDividendsResponse,
    StockMarketStats,
    StockQuoteDetailResponse,
    StockScreenerResponse,
    StockFinancialsResponse,
    StockCompareResponse,
    StockCompareItem,
)
from app.clients.brapi.stock_mapper import (
    STOCK_DETAIL_MODULES,
    STOCK_FINANCIALS_MODULES,
    limit_to_range,
    map_market_quote,
    map_market_stats,
    map_screener_item,
    map_stock_candles,
    map_stock_dividends,
    map_stock_financials,
    map_stock_compare_item,
    map_stock_fundamentals,
    map_stock_profile,
    normalize_candle_range,
    normalize_sort_by,
)
from app.clients.bolsai.models import (
    FiiCandlesResponse,
    FiiDetail,
    FiiDistributions,
    FiiHistoryResponse,
)
from app.config import settings
from app.core.exceptions import UpstreamError
from app.domain.fii.ticker import normalize_fii_ticker
from app.domain.quotes.category_map import infer_category
from app.providers.registry import AssetClass


class BrapiClient:
    """Cliente HTTP da Brapi — cotações e dados core de FIIs."""

    MAX_BATCH = 20

    def __init__(self, api_key: str | None = None, base_url: str | None = None) -> None:
        self._api_key = api_key if api_key is not None else settings.brapi_api_key
        self._base_url = (base_url or settings.brapi_base_url).rstrip("/")

    def _auth_params(self) -> dict[str, str]:
        if not self._api_key:
            return {}
        return {"token": self._api_key}

    def _auth_headers(self) -> dict[str, str]:
        if not self._api_key:
            return {}
        return {"Authorization": f"Bearer {self._api_key}"}

    async def _request(
        self,
        path: str,
        *,
        params: dict | None = None,
        use_bearer: bool = False,
    ) -> dict:
        query = dict(params or {})
        headers = self._auth_headers() if use_bearer else None
        if not use_bearer:
            query.update(self._auth_params())
        url = f"{self._base_url}/{path.lstrip('/')}"

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.get(url, params=query or None, headers=headers)
        except httpx.RequestError as exc:
            raise UpstreamError(
                f"Falha ao conectar na Brapi: {exc.__class__.__name__}",
                status_code=502,
            ) from exc

        if response.status_code == 404:
            raise UpstreamError("Ativo não encontrado", status_code=404)
        if response.status_code == 429:
            raise UpstreamError("Limite de requisições da Brapi excedido", status_code=429)
        if response.status_code >= 400:
            raise UpstreamError(
                f"Erro Brapi ({response.status_code}): {response.text[:200]}",
                status_code=502,
            )

        return response.json()

    async def _get(self, path: str, params: dict | None = None) -> dict:
        return await self._request(path, params=params, use_bearer=False)

    async def _get_v2(self, path: str, params: dict | None = None) -> dict:
        return await self._request(path, params=params, use_bearer=True)

    async def get_quotes(self, tickers: list[str]) -> list[MarketQuote]:
        if not tickers:
            return []

        unique = []
        seen: set[str] = set()
        for ticker in tickers:
            normalized = ticker.upper().strip()
            if normalized and normalized not in seen:
                seen.add(normalized)
                unique.append(normalized)

        if len(unique) > self.MAX_BATCH:
            raise UpstreamError(
                f"Máximo de {self.MAX_BATCH} tickers por requisição",
                status_code=400,
            )

        data = await self._get(f"/quote/{','.join(unique)}")
        results = data.get("results") or []
        return [self._map_quote_item(item) for item in results if item.get("symbol")]

    async def list_quotes(
        self,
        *,
        search: str | None = None,
        quote_type: str | None = None,
        limit: int = 20,
        page: int = 1,
        sort_by: str = "volume",
        sort_order: str = "desc",
    ) -> list[MarketQuote]:
        params: dict[str, str | int] = {
            "limit": limit,
            "page": page,
            "sortBy": sort_by,
            "sortOrder": sort_order,
        }
        if search:
            params["search"] = search
        if quote_type:
            params["type"] = quote_type

        data = await self._get("/quote/list", params=params)
        stocks = data.get("stocks") or []
        return [self._map_list_item(item) for item in stocks if item.get("stock")]

    async def screener_quotes(
        self,
        *,
        sector: str | None = None,
        quote_type: str = "stock",
        search: str | None = None,
        sort_by: str = "volume",
        sort_order: str = "desc",
        limit: int = 50,
        page: int = 1,
    ) -> StockScreenerResponse:
        params: dict[str, str | int] = {
            "limit": limit,
            "page": page,
            "sortBy": normalize_sort_by(sort_by),
            "sortOrder": sort_order,
            "type": quote_type,
        }
        if sector:
            params["sector"] = sector
        if search:
            params["search"] = search

        data = await self._get("/quote/list", params=params)
        stocks = data.get("stocks") or []
        items = [map_screener_item(item) for item in stocks if item.get("stock")]

        if quote_type == "stock":
            items = [
                item
                for item in items
                if infer_category(item.symbol, "stock") == AssetClass.STOCK_BR
            ]
        elif quote_type == "bdr":
            items = [item for item in items if infer_category(item.symbol, "bdr") == AssetClass.BDR]

        return StockScreenerResponse(
            items=items,
            count=len(items),
            total=data.get("totalCount"),
            page=data.get("currentPage") or page,
            total_pages=data.get("totalPages"),
            sectors=data.get("availableSectors") or [],
        )

    async def _get_stock_quote_item(
        self,
        ticker: str,
        *,
        range_: str = "1y",
        dividends: bool = False,
        modules: str | None = None,
    ) -> dict:
        normalized = ticker.upper().strip()
        params: dict[str, str] = {"range": range_, "interval": "1d"}
        if dividends:
            params["dividends"] = "true"
        if modules:
            params["modules"] = modules

        data = await self._get(f"/quote/{normalized}", params=params)
        results = data.get("results") or []
        if not results:
            raise UpstreamError("Ativo não encontrado", status_code=404)
        return results[0]

    async def get_stock_candles(
        self,
        ticker: str,
        *,
        limit: int = 252,
        range_: str | None = None,
    ) -> FiiCandlesResponse:
        normalized = ticker.upper().strip()
        brapi_range = normalize_candle_range(range_, limit=limit)
        item = await self._get_stock_quote_item(normalized, range_=brapi_range)
        prices = item.get("historicalDataPrice") or []
        trim = limit if range_ is None else (5000 if brapi_range == "max" else None)
        return map_stock_candles(ticker=normalized, price_points=prices, limit=trim)

    async def get_stock_dividends(self, ticker: str, *, limit: int = 24) -> StockDividendsResponse:
        normalized = ticker.upper().strip()
        item = await self._get_stock_quote_item(normalized, dividends=True)
        return map_stock_dividends(
            ticker=normalized,
            dividends_data=item.get("dividendsData"),
            limit=limit,
        )

    async def get_stock_detail(
        self,
        ticker: str,
        *,
        candle_limit: int = 252,
        dividend_limit: int = 120,
    ) -> StockQuoteDetailResponse:
        normalized = ticker.upper().strip()
        item = await self._get_stock_quote_item(
            normalized,
            range_=limit_to_range(candle_limit),
            dividends=True,
            modules=STOCK_DETAIL_MODULES,
        )
        quote = map_market_quote(item)
        candles = map_stock_candles(
            ticker=normalized,
            price_points=item.get("historicalDataPrice") or [],
            limit=candle_limit,
        )
        dividends = map_stock_dividends(
            ticker=normalized,
            dividends_data=item.get("dividendsData"),
            limit=dividend_limit,
        )
        fundamentals = map_stock_fundamentals(item)
        return StockQuoteDetailResponse(
            quote=quote,
            market_stats=map_market_stats(item),
            profile=map_stock_profile(item),
            fundamentals=fundamentals,
            candles=candles.candles,
            dividends=dividends,
        )

    async def get_stock_financials(self, ticker: str, *, limit: int = 8) -> StockFinancialsResponse:
        normalized = ticker.upper().strip()
        item = await self._get_stock_quote_item(
            normalized,
            range_="1mo",
            modules=STOCK_FINANCIALS_MODULES,
        )
        return map_stock_financials(ticker=normalized, item=item, limit=limit)

    async def get_stock_compare(self, tickers: list[str]) -> StockCompareResponse:
        unique: list[str] = []
        seen: set[str] = set()
        for ticker in tickers:
            normalized = ticker.upper().strip()
            if normalized and normalized not in seen:
                seen.add(normalized)
                unique.append(normalized)

        if not unique:
            return StockCompareResponse(items=[], count=0)
        if len(unique) > 3:
            raise UpstreamError("Máximo de 3 tickers por comparação", status_code=400)

        items = await asyncio.gather(*[self._fetch_compare_item(ticker) for ticker in unique])
        return StockCompareResponse(items=list(items), count=len(items))

    async def _fetch_compare_item(self, ticker: str) -> StockCompareItem:
        item = await self._get_stock_quote_item(
            ticker,
            range_="1mo",
            modules=STOCK_DETAIL_MODULES,
        )
        return map_stock_compare_item(item)

    def _map_quote_item(self, item: dict) -> MarketQuote:
        symbol = str(item["symbol"]).upper()
        name = item.get("longName") or item.get("shortName") or symbol
        price = float(item.get("regularMarketPrice") or 0)
        change = float(item.get("regularMarketChangePercent") or 0)
        asset_class = infer_category(symbol, item.get("type") or item.get("quoteType"))
        from app.domain.quotes.category_map import category_to_slug

        return MarketQuote(
            symbol=symbol,
            name=name,
            price=price,
            change_percent=change,
            category=category_to_slug(asset_class),
        )

    def _map_list_item(self, item: dict) -> MarketQuote:
        symbol = str(item["stock"]).upper()
        name = item.get("name") or symbol
        price = float(item.get("close") or 0)
        change = float(item.get("change") or 0)
        asset_class = infer_category(symbol, item.get("type"))
        from app.domain.quotes.category_map import category_to_slug

        return MarketQuote(
            symbol=symbol,
            name=name,
            price=price,
            change_percent=change,
            category=category_to_slug(asset_class),
        )

    async def get_fii_indicators(self, ticker: str) -> dict:
        normalized = normalize_fii_ticker(ticker)
        data = await self._get_v2(
            "v2/fii/indicators",
            params={"symbols": normalized},
        )
        items = data.get("fiis") or []
        if not items:
            raise UpstreamError("FII não encontrado", status_code=404)
        return items[0]

    async def get_fii_report(self, ticker: str) -> dict | None:
        normalized = normalize_fii_ticker(ticker)
        data = await self._get_v2(
            "v2/fii/reports",
            params={"symbols": normalized, "limit": 1},
        )
        reports = data.get("reports") or []
        return reports[0] if reports else None

    async def get_fii_distributions(
        self,
        ticker: str,
        *,
        years: int = 5,
        close_price: float | None = None,
        dividend_yield_ttm: float | None = None,
    ) -> FiiDistributions:
        normalized = normalize_fii_ticker(ticker)
        limit = max(years * 14, 24)
        data = await self._get_v2(
            "v2/fii/dividends",
            params={"symbols": normalized, "limit": limit},
        )
        dividends = [
            item
            for item in (data.get("dividends") or [])
            if str(item.get("symbol", "")).upper() == normalized
        ]
        if not dividends:
            raise UpstreamError("FII não encontrado", status_code=404)

        indicators = await self.get_fii_indicators(normalized)
        name = indicators.get("name") or normalized
        dy = indicators.get("dividendYield12m")
        return map_distributions(
            ticker=normalized,
            name=name,
            dividends=dividends,
            close_price=close_price or indicators.get("price"),
            dividend_yield_ttm=dividend_yield_ttm or pct_from_ratio(dy),
        )

    async def get_fii_history(self, ticker: str, *, limit: int = 24) -> FiiHistoryResponse:
        normalized = normalize_fii_ticker(ticker)
        data = await self._get_v2(
            "v2/fii/indicators/history",
            params={"symbols": normalized, "limit": limit},
        )
        entries = [
            item
            for item in (data.get("history") or [])
            if str(item.get("symbol", "")).upper() == normalized
        ]
        if not entries:
            raise UpstreamError("FII não encontrado", status_code=404)

        indicators = await self.get_fii_indicators(normalized)
        return map_history(
            ticker=normalized,
            name=indicators.get("name") or normalized,
            entries=entries,
        )

    async def get_fii_candles(
        self,
        ticker: str,
        *,
        limit: int = 252,
        start: str | None = None,
        end: str | None = None,
    ) -> FiiCandlesResponse:
        normalized = normalize_fii_ticker(ticker)
        range_ = "5y" if limit > 365 else "1y" if limit > 90 else "3mo"
        params: dict[str, str | int] = {
            "symbols": normalized,
            "range": range_,
            "interval": "1d",
        }
        if start:
            params["startDate"] = start
        if end:
            params["endDate"] = end

        data = await self._get_v2("v2/fii/historical", params=params)
        series = data.get("fiis") or []
        if not series:
            raise UpstreamError("FII não encontrado", status_code=404)

        prices = series[0].get("historicalDataPrice") or []
        candles = map_candles(ticker=normalized, price_points=prices)
        if limit and len(candles.candles) > limit:
            candles = FiiCandlesResponse(
                ticker=candles.ticker,
                count=limit,
                candles=candles.candles[-limit:],
                provider=candles.provider,
            )
        return candles

    async def build_fii_detail(self, ticker: str, bolsai: FiiDetail) -> FiiDetail:
        normalized = normalize_fii_ticker(ticker)
        indicators = await self.get_fii_indicators(normalized)
        report = await self.get_fii_report(normalized)
        return merge_fii_detail(
            ticker=normalized,
            indicators=indicators,
            report=report,
            bolsai=bolsai,
        )
