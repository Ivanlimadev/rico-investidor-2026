from pydantic import BaseModel


class CryptoQuote(BaseModel):
    symbol: str
    name: str
    currency: str = "USD"
    price: float
    change_percent: float = 0.0
    change: float | None = None
    day_high: float | None = None
    day_low: float | None = None
    volume: float | None = None
    market_cap: float | None = None
    image_url: str | None = None
    updated_at: str | None = None
    bid_price: float | None = None
    ask_price: float | None = None
    spread: float | None = None
    spread_percent: float | None = None
    provider: str = "binance"


class CryptoListResponse(BaseModel):
    items: list[CryptoQuote]
    count: int
    provider: str = "binance"


class CryptoAvailableResponse(BaseModel):
    coins: list[str]
    count: int
    provider: str = "binance"


class CryptoExploreResponse(BaseModel):
    items: list[CryptoQuote]
    count: int
    total: int
    page: int
    total_pages: int
    group: str = "all"
    provider: str = "binance"


class CryptoCandle(BaseModel):
    date: str
    open: float
    high: float
    low: float
    close: float
    volume: float


class CryptoCandlesResponse(BaseModel):
    symbol: str
    currency: str = "USD"
    interval: str
    candles: list[CryptoCandle]
    count: int
    provider: str = "binance"


class CryptoHistoryPoint(BaseModel):
    date: str
    value: float


class CryptoHistoryResponse(BaseModel):
    symbol: str
    currency: str = "USD"
    history: list[CryptoHistoryPoint]
    count: int
    provider: str = "binance"


class CryptoOrderBookLevel(BaseModel):
    price: float
    quantity: float


class CryptoOrderBook(BaseModel):
    symbol: str
    bids: list[CryptoOrderBookLevel]
    asks: list[CryptoOrderBookLevel]
    provider: str = "binance"


class CryptoRecentTrade(BaseModel):
    id: int
    price: float
    quantity: float
    time: str
    is_buyer_maker: bool


class CryptoRecentTradesResponse(BaseModel):
    symbol: str
    trades: list[CryptoRecentTrade]
    count: int
    provider: str = "binance"


class CryptoMarketSnapshot(BaseModel):
    quote: CryptoQuote
    order_book: CryptoOrderBook
    trades: CryptoRecentTradesResponse
    provider: str = "binance"


class CryptoMoversResponse(BaseModel):
    gainers: list[CryptoQuote]
    losers: list[CryptoQuote]
    limit: int
    provider: str = "binance"


class CryptoPerformanceStats(BaseModel):
    change_24h: float | None = None
    change_7d: float | None = None
    change_30d: float | None = None
    change_1y: float | None = None


class CryptoFundamentals(BaseModel):
    market_cap: float | None = None
    market_cap_rank: int | None = None
    circulating_supply: float | None = None
    total_supply: float | None = None
    ath: float | None = None
    ath_change_percent: float | None = None
    atl: float | None = None
    categories: list[str] = []


class CryptoBrlSnapshot(BaseModel):
    price: float | None = None
    usdt_brl_rate: float | None = None


class CryptoInvestorProfile(BaseModel):
    symbol: str
    quote: CryptoQuote
    performance: CryptoPerformanceStats
    fundamentals: CryptoFundamentals
    brl: CryptoBrlSnapshot
    provider: str = "binance+coingecko"


class CryptoMacroSnapshot(BaseModel):
    btc_dominance: float | None = None
    total_market_cap_usd: float | None = None
    total_volume_24h_usd: float | None = None
    fear_greed_index: int | None = None
    fear_greed_label: str | None = None
    usdt_brl_rate: float | None = None
    provider: str = "coingecko+alternative.me+binance"
