from pydantic import BaseModel, Field


class IndexQuote(BaseModel):
    symbol: str
    name: str
    group: str
    price: float
    change_percent: float
    day_high: float | None = None
    day_low: float | None = None
    previous_close: float | None = None
    fifty_two_week_high: float | None = None
    fifty_two_week_low: float | None = None
    provider: str = "brapi"


class IndexListResponse(BaseModel):
    items: list[IndexQuote]
    count: int
    provider: str = "brapi"


class IndexExploreResponse(BaseModel):
    items: list[IndexQuote]
    count: int
    total: int
    page: int
    total_pages: int
    group: str = "all"
    provider: str = "brapi"


class IndexHistoryPoint(BaseModel):
    date: str
    value: float


class IndexHistoryResponse(BaseModel):
    symbol: str
    history: list[IndexHistoryPoint] = Field(default_factory=list)
    count: int = 0
    provider: str = "brapi"


class IndexDetailResponse(BaseModel):
    quote: IndexQuote
    history: list[IndexHistoryPoint] = Field(default_factory=list)
    provider: str = "brapi"
