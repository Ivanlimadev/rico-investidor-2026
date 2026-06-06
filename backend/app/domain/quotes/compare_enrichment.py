from __future__ import annotations

from datetime import UTC, date, datetime

from app.clients.brapi.models import (
    StockCompareDividendsSnapshot,
    StockCompareReturnPeriod,
    StockDividendsResponse,
    StockFundamentals,
)
from app.clients.bolsai.client import BolsaiClient
from app.clients.bolsai.fundamentals_mapper import merge_bolsai_fundamentals
from app.domain.fii.models import FiiCandleBar, FiiDistributionPayment
from app.domain.global_markets.models import GlobalStockDividendsSummary, GlobalStockReturnPeriod
from app.domain.dividends.br_dividend_analytics import (
    resolve_display_dividend_yield,
    resolve_display_ttm_per_share,
)
from app.domain.quotes.stock_returns import compute_stock_returns

_COMPARE_1M_SESSIONS = 21
_COMPARE_RETURN_LABELS = frozenset({"1M", "YTD", "1A"})


def dividends_snapshot_from_stock(
    dividends: StockDividendsResponse,
) -> StockCompareDividendsSnapshot:
    summary = dividends.summary
    next_ev = summary.next_dividend
    return StockCompareDividendsSnapshot(
        dividend_yield_display=resolve_display_dividend_yield(
            dividend_yield_display=summary.dividend_yield_display,
            dividend_yield_ttm=dividends.dividend_yield_ttm,
        ),
        dividend_yield_ttm=dividends.dividend_yield_ttm,
        ttm_per_share=resolve_display_ttm_per_share(
            ttm_per_share_display=summary.ttm_per_share_display,
            ttm_per_share=dividends.ttm_per_share,
        ),
        frequency_label=summary.frequency_label,
        payments_12m=summary.payments_12m,
        next_com_date=next_ev.com_date if next_ev else None,
        next_payment_date=next_ev.payment_date if next_ev else None,
        next_amount=next_ev.value_per_share if next_ev else None,
        provider=dividends.provider,
    )


def dividends_snapshot_from_global(
    summary: GlobalStockDividendsSummary,
    *,
    provider: str = "marketstack",
) -> StockCompareDividendsSnapshot:
    next_ev = summary.next_dividend
    return StockCompareDividendsSnapshot(
        dividend_yield_display=summary.dividend_yield_ttm,
        dividend_yield_ttm=summary.dividend_yield_ttm,
        ttm_per_share=summary.ttm_per_share,
        frequency_label=summary.frequency_label,
        payments_12m=summary.payments_12m or None,
        next_com_date=next_ev.com_date if next_ev else None,
        next_payment_date=next_ev.payment_date if next_ev else None,
        next_amount=next_ev.amount if next_ev else None,
        provider=provider,
    )


def return_periods_from_global(
    rows: list[GlobalStockReturnPeriod],
) -> list[StockCompareReturnPeriod]:
    return [
        StockCompareReturnPeriod(label=row.label, return_pct=row.return_pct)
        for row in rows
        if row.return_pct is not None
    ]


def _return_pct_between(start: float, end: float) -> float | None:
    if start <= 0 or end <= 0:
        return None
    return round(((end / start) - 1) * 100, 4)


def _price_sessions_back(candles: list[FiiCandleBar], sessions_back: int) -> float | None:
    if not candles or sessions_back < 1:
        return None
    index = max(0, len(candles) - 1 - sessions_back)
    price = candles[index].close
    return price if price > 0 else None


def _ytd_start_price(candles: list[FiiCandleBar], *, as_of: date) -> float | None:
    year_prefix = f"{as_of.year}-"
    for bar in candles:
        if bar.trade_date.startswith(year_prefix):
            return bar.close if bar.close > 0 else None
    return None


def compare_return_periods_from_candles(
    candles: list[FiiCandleBar],
    *,
    current_price: float | None = None,
    payments: list[FiiDistributionPayment] | None = None,
    as_of: date | None = None,
) -> list[StockCompareReturnPeriod]:
    """Rentabilidade para comparador — pregões + dividendos quando há histórico longo."""
    if not candles:
        return []

    ref_day = as_of or date.today()
    full = compute_stock_returns(
        candles,
        current_price=current_price,
        payments=payments or [],
        as_of=datetime(ref_day.year, ref_day.month, ref_day.day, tzinfo=UTC),
    )
    if full:
        return [
            StockCompareReturnPeriod(label=row.label, return_pct=row.return_pct)
            for row in full
            if row.label in _COMPARE_RETURN_LABELS and row.return_pct is not None
        ]

    return return_periods_from_ticker_candles(candles, as_of=as_of)


def return_periods_from_ticker_candles(
    candles: list[FiiCandleBar],
    *,
    as_of: date | None = None,
) -> list[StockCompareReturnPeriod]:
    """Deriva 1M, YTD e 1A de uma única série diária (~1y) — evita 3× performance/BVSP."""
    if not candles:
        return []

    sorted_candles = sorted(candles, key=lambda bar: bar.trade_date)
    latest_price = sorted_candles[-1].close
    if latest_price <= 0:
        return []

    one_month = None
    if len(sorted_candles) > _COMPARE_1M_SESSIONS:
        start_1m = _price_sessions_back(sorted_candles, _COMPARE_1M_SESSIONS)
        one_month = _return_pct_between(start_1m or 0, latest_price)

    one_year = _return_pct_between(sorted_candles[0].close, latest_price)

    ref = as_of or date.today()
    ytd_start = _ytd_start_price(sorted_candles, as_of=ref)
    ytd = _return_pct_between(ytd_start or 0, latest_price) if ytd_start else None

    return return_periods_from_performance(one_month=one_month, ytd=ytd, one_year=one_year)


def return_periods_from_performance(
    *,
    one_month: float | None,
    one_year: float | None,
    ytd: float | None = None,
) -> list[StockCompareReturnPeriod]:
    rows: list[StockCompareReturnPeriod] = []
    if one_month is not None:
        rows.append(StockCompareReturnPeriod(label="1M", return_pct=one_month))
    if ytd is not None:
        rows.append(StockCompareReturnPeriod(label="YTD", return_pct=ytd))
    if one_year is not None:
        rows.append(StockCompareReturnPeriod(label="1A", return_pct=one_year))
    return rows


async def merge_bolsai_fundamentals_for_ticker(
    fundamentals: StockFundamentals,
    *,
    ticker: str,
    bolsai: BolsaiClient,
) -> StockFundamentals:
    if not bolsai.configured:
        return fundamentals
    try:
        from app.services.br_proventos_service import br_proventos_service

        payload = await br_proventos_service.get_fundamentals_cached(ticker)
    except Exception:
        return fundamentals
    if not payload:
        return fundamentals
    return merge_bolsai_fundamentals(fundamentals, payload)
