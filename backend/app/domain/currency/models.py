from pydantic import BaseModel, Field


class CurrencyPairSummary(BaseModel):
    pair: str
    name: str


class CurrencyPairListResponse(BaseModel):
    pairs: list[CurrencyPairSummary]
    count: int
    provider: str = "brapi"


class CurrencyQuote(BaseModel):
    pair: str
    name: str
    from_currency: str
    to_currency: str
    bid_price: float | None = None
    ask_price: float | None = None
    high: float | None = None
    low: float | None = None
    bid_variation: float | None = None
    change_percent: float | None = None
    updated_at: str | None = None
    provider: str = "brapi"


class CurrencyListResponse(BaseModel):
    items: list[CurrencyQuote]
    count: int
    provider: str = "brapi"


class CurrencyExploreResponse(BaseModel):
    items: list[CurrencyQuote]
    count: int
    total: int
    page: int
    total_pages: int
    group: str = "all"
    provider: str = "brapi"


class CurrencyHistoryPoint(BaseModel):
    date: str
    value: float


class CurrencyHistoryResponse(BaseModel):
    pair: str
    from_currency: str
    to_currency: str
    history: list[CurrencyHistoryPoint]
    count: int
    provider: str = "brapi"
