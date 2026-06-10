from pydantic import BaseModel, Field


class PriceAlertCreateRequest(BaseModel):
    symbol: str = Field(min_length=1, max_length=32)
    category: str = Field(default="stocks", max_length=32)
    direction: str = Field(pattern=r"^(above|below)$")
    target_price: float = Field(gt=0)


class PriceAlertResponse(BaseModel):
    id: str
    symbol: str
    category: str
    direction: str
    target_price: float
    enabled: bool


class PriceAlertListResponse(BaseModel):
    items: list[PriceAlertResponse]
    count: int
