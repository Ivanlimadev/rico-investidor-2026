from pydantic import BaseModel, Field


class BolsaiDividendPayment(BaseModel):
    ex_date: str | None = None
    payment_date: str | None = None
    type: str | None = None
    value_per_share: float | None = None
    reference_date: str | None = None
    dy_month_pct: float | None = None
    book_value_per_share: float | None = None


class BolsaiAnnualSummary(BaseModel):
    year: int
    total_per_share: float | None = None
    payments: int | None = None


class BolsaiDividendsResponse(BaseModel):
    ticker: str
    name: str | None = None
    dividend_yield_ttm: float | None = None
    ttm_per_share: float | None = None
    current_price: float | None = None
    close_price: float | None = None
    total_payments: int | None = None
    annual_summary: list[BolsaiAnnualSummary] = Field(default_factory=list)
    payments: list[BolsaiDividendPayment] = Field(default_factory=list)
