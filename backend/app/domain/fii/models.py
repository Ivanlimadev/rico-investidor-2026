from pydantic import BaseModel, Field, field_validator


def _none_to_list(value):
    return value if value is not None else []


class FiiListItem(BaseModel):
    ticker: str
    name: str
    segment: str | None = None
    management_type: str | None = None
    total_shareholders: int | None = None


class FiiListResponse(BaseModel):
    count: int
    total: int
    fiis: list[FiiListItem]
    provider: str = "brapi"


class FiiAssetComposition(BaseModel):
    real_estate_leased_pct: float | None = None
    real_estate_under_construction_pct: float | None = None
    real_estate_for_sale_pct: float | None = None
    land_pct: float | None = None
    other_real_estate_pct: float | None = None
    cri_pct: float | None = None
    lci_pct: float | None = None
    cepac_pct: float | None = None
    debentures_pct: float | None = None
    fii_holdings_pct: float | None = None
    fip_fdic_pct: float | None = None
    stocks_pct: float | None = None
    cash_pct: float | None = None
    other_pct: float | None = None


class FiiFeesPaid(BaseModel):
    admin: float | None = None
    performance: float | None = None


class FiiProperty(BaseModel):
    name: str
    address: str | None = None
    asset_class: str | None = None
    area_sqm: float | None = None
    revenue_pct: float | None = None
    vacancy_pct: float | None = None
    leased_pct: float | None = None


class FiiDetail(BaseModel):
    ticker: str
    name: str
    reference_date: str | None = None
    close_price: float | None = None
    book_value_per_share: float | None = None
    pvp: float | None = None
    dividend_yield_ttm: float | None = None
    net_asset_value: float | None = None
    shares_outstanding: float | None = None
    total_shareholders: int | None = None
    segment: str | None = None
    management_type: str | None = None
    administrator: str | None = None
    administrator_cnpj: str | None = None
    mandate: str | None = None
    inception_date: str | None = None
    duration_type: str | None = None
    target_investors: str | None = None
    website: str | None = None
    email: str | None = None
    fund_type: str | None = None
    asset_composition: FiiAssetComposition | None = None
    fees_paid_last_month: FiiFeesPaid | None = None
    property_count: int | None = None
    total_area_sqm: float | None = None
    vacancy_pct: float | None = None
    delinquency_pct: float | None = None
    leased_pct: float | None = None
    top_properties: list[FiiProperty] = Field(default_factory=list)
    property_reference_date: str | None = None
    provider: str = "brapi"

    @field_validator("top_properties", mode="before")
    @classmethod
    def _top_properties_none(cls, value):
        return _none_to_list(value)


class FiiDistributionPayment(BaseModel):
    reference_date: str | None = None
    payment_date: str | None = None
    value_per_share: float | None = None
    dy_month_pct: float | None = None
    book_value_per_share: float | None = None
    label: str | None = None


class FiiDistributionYearSummary(BaseModel):
    year: int
    total_per_share: float | None = None
    payments: int | None = None


class FiiDistributions(BaseModel):
    ticker: str
    name: str
    dividend_yield_ttm: float | None = None
    ttm_per_share: float | None = None
    close_price: float | None = None
    total_payments: int | None = None
    annual_summary: list[FiiDistributionYearSummary] = Field(default_factory=list)
    payments: list[FiiDistributionPayment] = Field(default_factory=list)
    provider: str = "brapi"

    @field_validator("annual_summary", "payments", mode="before")
    @classmethod
    def _list_fields_none(cls, value):
        return _none_to_list(value)


class FiiHistoryPoint(BaseModel):
    reference_date: str | None = None
    close_price: float | None = None
    book_value_per_share: float | None = None
    pvp: float | None = None
    dy_month_pct: float | None = None
    value_per_share: float | None = None
    net_asset_value: float | None = None
    total_shareholders: int | None = None


class FiiHistoryResponse(BaseModel):
    ticker: str
    name: str
    count: int
    history: list[FiiHistoryPoint]
    provider: str = "brapi"

    @field_validator("history", mode="before")
    @classmethod
    def _history_none(cls, value):
        return _none_to_list(value)


class FiiCandleBar(BaseModel):
    trade_date: str
    open: float
    high: float
    low: float
    close: float
    volume: float | None = None


class FiiCandlesResponse(BaseModel):
    ticker: str
    count: int
    candles: list[FiiCandleBar] = Field(default_factory=list)
    provider: str = "brapi"
    interval: str | None = None
    range: str | None = None

    @field_validator("candles", mode="before")
    @classmethod
    def _candles_none(cls, value):
        return _none_to_list(value)


class FiiTenantSector(BaseModel):
    sector: str
    revenue_pct: float | None = None


class FiiTenantsResponse(BaseModel):
    ticker: str
    reference_date: str | None = None
    count: int | None = None
    top_sector_pct: float | None = None
    sectors: list[FiiTenantSector] = Field(default_factory=list)
    provider: str = "brapi"

    @field_validator("sectors", mode="before")
    @classmethod
    def _sectors_none(cls, value):
        return _none_to_list(value)


class FiiSearchResponse(BaseModel):
    query: str
    count: int
    total: int
    fiis: list[FiiListItem]
    provider: str = "brapi"


class FiiScreenerItem(BaseModel):
    ticker: str
    name: str
    segment: str | None = None
    management_type: str | None = None
    mandate: str | None = None
    administrator_name: str | None = None
    fund_type: str | None = None
    reference_date: str | None = None
    close_price: float | None = None
    book_value_per_share: float | None = None
    net_asset_value: float | None = None
    shares_outstanding: float | None = None
    total_shareholders: int | None = None
    pvp: float | None = None
    dividend_yield_ttm: float | None = None
    dy_month_pct: float | None = None
    vacancy_pct: float | None = None
    delinquency_pct: float | None = None
    leased_pct: float | None = None
    property_count: int | None = None
    total_area_sqm: float | None = None
    provider: str = "brapi"


class FiiScreenerResponse(BaseModel):
    data: list[FiiScreenerItem]
    count: int
    total: int
    offset: int
    limit: int
    provider: str = "brapi"
