from typing import Literal

from pydantic import BaseModel, Field

from app.domain.fii.models import FiiDetail
from app.clients.brapi.models import StockQuoteDetailResponse


class AssetDetailResponse(BaseModel):
    """Detalhe unificado — o backend escolhe Brapi para ações e FIIs."""

    ticker: str
    asset_class: str
    category: str
    provider: str
    kind: Literal["stock", "fii"]
    sections: list[str] = Field(default_factory=list)
    notes: list[str] = Field(default_factory=list)
    stock: StockQuoteDetailResponse | None = None
    fii: FiiDetail | None = None
