from app.domain.assets.models import AssetDetailResponse
from app.domain.assets.resolver import normalize_asset_ticker, resolve_asset_class
from app.domain.assets.sections import stock_notes, stock_sections
from app.domain.quotes.category_map import category_to_slug
from app.providers.registry import AssetClass
from app.services.fii_service import fii_service
from app.services.quote_service import quote_service

_FII_SECTIONS = (
    "quote",
    "fundamentals",
    "properties",
    "distributions",
    "history",
    "tenants",
)


class AssetService:
    """Roteia um ticker para o serviço correto — uma chamada upstream por abertura."""

    async def get_detail(
        self,
        ticker: str,
        *,
        candle_limit: int = 252,
        dividend_limit: int = 120,
    ) -> AssetDetailResponse:
        asset_class = resolve_asset_class(ticker)
        normalized = normalize_asset_ticker(ticker)

        if asset_class == AssetClass.FII:
            detail = await fii_service.get_fii(normalized)
            return AssetDetailResponse(
                ticker=detail.ticker,
                asset_class=asset_class.value,
                category=category_to_slug(asset_class),
                provider=detail.provider,
                kind="fii",
                sections=list(_FII_SECTIONS),
                fii=detail,
            )

        stock = await quote_service.get_stock_detail(
            normalized,
            candle_limit=candle_limit,
            dividend_limit=dividend_limit,
        )
        category = category_to_slug(asset_class)
        if asset_class == AssetClass.STOCK_BR:
            category = stock.quote.category or category

        return AssetDetailResponse(
            ticker=stock.quote.symbol,
            asset_class=asset_class.value,
            category=category,
            provider=stock.provider,
            kind="stock",
            sections=stock_sections(stock, asset_class),
            notes=stock_notes(stock, asset_class),
            stock=stock,
        )


asset_service = AssetService()
