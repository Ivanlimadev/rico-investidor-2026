from __future__ import annotations

from app.clients.brapi.models import FundamentalHistoryPeriod, StockFundamentalHistoryResponse
from app.domain.fii.models import FiiCandleBar, FiiCandlesResponse


def _rows(payload: dict) -> list[dict]:
    for key in ("history", "data", "prices", "candles", "items", "periods"):
        raw = payload.get(key)
        if isinstance(raw, list):
            return [row for row in raw if isinstance(row, dict)]
    return []


def map_bolsai_stock_candles(ticker: str, payload: dict, *, limit: int) -> FiiCandlesResponse:
    bars: list[FiiCandleBar] = []
    for row in _rows(payload):
        date = (
            row.get("trade_date")
            or row.get("date")
            or row.get("session_date")
            or row.get("trading_date")
        )
        close = (
            row.get("adjusted_close")
            or row.get("adj_close")
            or row.get("close")
        )
        if not date or close is None:
            continue
        try:
            close_f = float(close)
        except (TypeError, ValueError):
            continue
        if close_f <= 0:
            continue
        open_raw = row.get("adjusted_open") or row.get("open")
        high_raw = row.get("adjusted_high") or row.get("high")
        low_raw = row.get("adjusted_low") or row.get("low")
        open_ = _optional_float(open_raw) or close_f
        high = _optional_float(high_raw) or close_f
        low = _optional_float(low_raw) or close_f
        bars.append(
            FiiCandleBar(
                trade_date=str(date).split("T", 1)[0],
                open=open_,
                high=high,
                low=low,
                close=close_f,
                volume=_optional_float(row.get("adjusted_volume") or row.get("volume")),
            )
        )
    bars.sort(key=lambda b: b.trade_date)
    if limit > 0:
        bars = bars[-limit:]
    return FiiCandlesResponse(ticker=ticker, candles=bars, count=len(bars), provider="bolsai")


def map_bolsai_fundamental_history(
    ticker: str,
    payload: dict,
    *,
    limit: int,
) -> StockFundamentalHistoryResponse:
    periods: list[FundamentalHistoryPeriod] = []
    for row in _rows(payload):
        end = (
            row.get("reference_date")
            or row.get("end_date")
            or row.get("period_end")
            or row.get("date")
        )
        if not end:
            continue
        periods.append(
            FundamentalHistoryPeriod(
                end_date=str(end).split("T", 1)[0],
                total_revenue=_optional_float(
                    row.get("net_revenue") or row.get("total_revenue") or row.get("revenue")
                ),
                net_income=_optional_float(row.get("net_income")),
                ebitda=_optional_float(row.get("ebitda")),
                free_cashflow=_optional_float(row.get("free_cashflow") or row.get("fcf")),
                profit_margin=_optional_float(
                    row.get("net_margin") or row.get("profit_margin")
                ),
                return_on_equity=_optional_float(row.get("roe") or row.get("return_on_equity")),
                dividend_yield_12m=_optional_float(
                    row.get("dividend_yield") or row.get("dividend_yield_12m")
                ),
                price_earnings=_optional_float(row.get("pl") or row.get("pe") or row.get("price_earnings")),
                price_to_book=_optional_float(row.get("pvp") or row.get("price_to_book")),
                provider="bolsai",
            )
        )
    periods.sort(key=lambda p: p.end_date, reverse=True)
    if limit > 0:
        periods = periods[:limit]
    return StockFundamentalHistoryResponse(
        ticker=ticker,
        periods=periods,
        count=len(periods),
        provider="bolsai",
    )


def _optional_float(value: object) -> float | None:
    if value is None:
        return None
    try:
        return round(float(value), 4)
    except (TypeError, ValueError):
        return None
