from pydantic import BaseModel, Field


class RelatedAssetItem(BaseModel):
    symbol: str
    name: str
    price: float
    change_percent: float = 0.0
    category: str
    reason: str
    logo_url: str | None = None
    exchange_mic: str | None = None
    provider: str = ""


class RelatedAssetsResponse(BaseModel):
    ticker: str
    group_label: str
    items: list[RelatedAssetItem] = Field(default_factory=list)
    count: int = 0
    market: str = ""
