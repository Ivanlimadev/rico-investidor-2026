from pydantic import BaseModel, Field


class PortfolioHoldingPayload(BaseModel):
    symbol: str = Field(min_length=1, max_length=32)
    name: str = Field(min_length=1, max_length=120)
    quantity: float = Field(gt=0)
    average_price: float = Field(ge=0)
    current_price: float = Field(default=0, ge=0)
    change_percent: float = 0.0
    currency: str = Field(default="usd", min_length=2, max_length=8)
    category: str | None = Field(default=None, max_length=32)


class PortfolioHoldingCreateRequest(PortfolioHoldingPayload):
    id: str | None = Field(default=None, max_length=36)


class PortfolioHoldingUpdateRequest(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    quantity: float | None = Field(default=None, gt=0)
    average_price: float | None = Field(default=None, ge=0)
    current_price: float | None = Field(default=None, ge=0)
    change_percent: float | None = None
    currency: str | None = Field(default=None, min_length=2, max_length=8)
    category: str | None = Field(default=None, max_length=32)


class PortfolioHoldingResponse(BaseModel):
    id: str
    symbol: str
    name: str
    quantity: float
    average_price: float
    current_price: float
    change_percent: float
    currency: str
    category: str | None = None


class PortfolioHoldingsListResponse(BaseModel):
    items: list[PortfolioHoldingResponse]
    count: int


class PortfolioSyncRequest(BaseModel):
    items: list[PortfolioHoldingCreateRequest] = Field(default_factory=list, max_length=200)
