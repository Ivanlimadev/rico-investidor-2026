from pydantic import BaseModel, Field


class DividendCalendarEntry(BaseModel):
    market: str
    symbol: str
    company_name: str
    exchange: str | None = None
    dividend_type: str = "Dividendo"
    com_date: str
    payment_date: str | None = None
    amount: float
    currency: str


class DividendCalendarResponse(BaseModel):
    market: str
    sort_by: str
    days_ahead: int
    count: int
    items: list[DividendCalendarEntry] = Field(default_factory=list)
    data_sources: list[str] = Field(default_factory=list)
