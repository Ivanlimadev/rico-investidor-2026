from pydantic import BaseModel, Field


class TreasuryRateInfo(BaseModel):
    rate_type: str | None = None
    rate_unit: str | None = None
    description: str | None = None


class TreasuryBond(BaseModel):
    symbol: str
    bond_type: str
    indexer: str | None = None
    coupon_type: str | None = None
    maturity_date: str | None = None
    duration_days: int | None = None
    base_date: str | None = None
    buy_rate: float | None = None
    sell_rate: float | None = None
    buy_price: float | None = None
    sell_price: float | None = None
    base_price: float | None = None
    rate_info: TreasuryRateInfo | None = None
    provider: str = "brapi"


class TreasuryListResponse(BaseModel):
    items: list[TreasuryBond]
    count: int
    total: int
    page: int
    total_pages: int
    group: str = "all"
    provider: str = "brapi"


class TreasuryHistoryPoint(BaseModel):
    date: str
    buy_rate: float | None = None
    sell_rate: float | None = None
    buy_price: float | None = None
    sell_price: float | None = None
    base_price: float | None = None


class TreasuryHistoryResponse(BaseModel):
    symbol: str
    bond_type: str | None = None
    indexer: str | None = None
    coupon_type: str | None = None
    maturity_date: str | None = None
    rate_info: TreasuryRateInfo | None = None
    history: list[TreasuryHistoryPoint] = Field(default_factory=list)
    count: int = 0
    provider: str = "brapi"
