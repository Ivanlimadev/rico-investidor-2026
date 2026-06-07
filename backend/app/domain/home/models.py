from datetime import UTC, datetime

from pydantic import BaseModel, Field

from app.clients.brapi.models import MarketQuoteBatchResponse


class MarketCounts(BaseModel):
    fiis: int | None = None
    acoes_br: int | None = None
    bdr: int | None = None
    etf: int | None = None
    etf_intl: int | None = None
    moeda: int | None = None
    tesouro: int | None = None
    indices: int | None = None
    cripto: int | None = None
    stocks_us: int | None = None
    world_exchanges: int | None = None


class FeaturedFiisFeed(BaseModel):
    data: list = Field(default_factory=list)
    count: int = 0
    total: int = 0
    offset: int = 0
    limit: int = 0


class HomeFeedResponse(BaseModel):
    featured_us_stocks: MarketQuoteBatchResponse | None = None
    featured_stocks: MarketQuoteBatchResponse
    featured_fiis: FeaturedFiisFeed
    market_counts: MarketCounts = Field(default_factory=MarketCounts)
    macro: None = None
    provider: str = "marketstack"
    data_providers: dict[str, str] = Field(
        default_factory=lambda: {"us": "marketstack", "crypto": "binance"},
    )
    generated_at: datetime = Field(default_factory=lambda: datetime.now(UTC))
