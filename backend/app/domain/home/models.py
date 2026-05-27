from datetime import UTC, datetime

from pydantic import BaseModel, Field

from app.clients.brapi.models import BrazilMacroResponse, MarketQuoteBatchResponse
from app.domain.fii.models import FiiScreenerResponse


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


class HomeFeedResponse(BaseModel):
    featured_stocks: MarketQuoteBatchResponse
    featured_fiis: FiiScreenerResponse
    market_counts: MarketCounts = Field(default_factory=MarketCounts)
    macro: BrazilMacroResponse | None = None
    provider: str = "brapi"
    generated_at: datetime = Field(default_factory=lambda: datetime.now(UTC))
