from __future__ import annotations

from collections import defaultdict
from datetime import UTC, datetime

from app.clients.bolsai.models import (
    FiiAssetComposition,
    FiiCandleBar,
    FiiCandlesResponse,
    FiiDetail,
    FiiDistributionPayment,
    FiiDistributionYearSummary,
    FiiDistributions,
    FiiFeesPaid,
    FiiHistoryPoint,
    FiiHistoryResponse,
)


def normalize_reference_date(value: str | None) -> str | None:
    if not value:
        return None
    return value.split(" ", 1)[0]


def pct_from_ratio(value: float | None) -> float | None:
    if value is None:
        return None
    return round(value * 100, 4)


def pct_of_total(part: float | None, total: float | None) -> float | None:
    if part is None or total is None or total == 0:
        return None
    return round((part / total) * 100, 4)


def map_asset_composition(report: dict) -> FiiAssetComposition | None:
    total = report.get("totalAssets")
    if not total:
        return None

    real_estate = report.get("realEstateAssets")
    fii_holdings = report.get("fiiHoldings")
    cri = report.get("cri")
    lci = report.get("lci")
    cash = report.get("cash")

    cash_pct = pct_of_total(cash, total)
    if cash_pct is None and isinstance(cash, (int, float)) and 0 <= cash <= 100:
        cash_pct = float(cash)

    return FiiAssetComposition(
        real_estate_leased_pct=pct_of_total(real_estate, total),
        cri_pct=pct_of_total(cri, total),
        lci_pct=pct_of_total(lci, total),
        fii_holdings_pct=pct_of_total(fii_holdings, total),
        cash_pct=cash_pct,
    )


def map_fees_paid(report: dict) -> FiiFeesPaid | None:
    admin_rate = report.get("adminFeeRate")
    if admin_rate is None:
        return None
    return FiiFeesPaid(admin=round(admin_rate * 100, 4))


def merge_fii_detail(
    *,
    ticker: str,
    indicators: dict,
    report: dict | None,
    bolsai: FiiDetail,
) -> FiiDetail:
    detail = bolsai.model_copy(deep=True)
    detail.ticker = ticker
    detail.name = indicators.get("name") or detail.name
    detail.reference_date = (
        normalize_reference_date(report.get("referenceDate") if report else None)
        or normalize_reference_date(indicators.get("asOfDate"))
        or detail.reference_date
    )
    detail.close_price = indicators.get("price") or detail.close_price
    detail.book_value_per_share = indicators.get("navPerShare") or detail.book_value_per_share
    detail.pvp = indicators.get("priceToNav") or detail.pvp
    dy = indicators.get("dividendYield12m")
    detail.dividend_yield_ttm = pct_from_ratio(dy) if dy is not None else detail.dividend_yield_ttm
    detail.net_asset_value = indicators.get("equity") or detail.net_asset_value
    detail.shares_outstanding = indicators.get("sharesOutstanding") or detail.shares_outstanding
    detail.total_shareholders = indicators.get("totalInvestors") or detail.total_shareholders
    detail.segment = indicators.get("segmentoAtuacao") or indicators.get("segmentType") or detail.segment
    detail.management_type = indicators.get("tipoGestao") or detail.management_type
    detail.administrator = indicators.get("administratorName") or detail.administrator
    detail.administrator_cnpj = indicators.get("administratorCnpj") or detail.administrator_cnpj
    detail.mandate = indicators.get("mandate") or detail.mandate
    detail.fund_type = indicators.get("segmentType") or detail.fund_type
    detail.website = indicators.get("administratorWebsite") or detail.website
    detail.email = indicators.get("administratorEmail") or detail.email

    if report:
        composition = map_asset_composition(report)
        if composition:
            detail.asset_composition = composition
        fees = map_fees_paid(report)
        if fees:
            detail.fees_paid_last_month = fees

    detail.provider = "brapi+bolsai"
    return detail


def map_distributions(
    *,
    ticker: str,
    name: str,
    dividends: list[dict],
    close_price: float | None = None,
    dividend_yield_ttm: float | None = None,
) -> FiiDistributions:
    payments: list[FiiDistributionPayment] = []
    by_year: dict[int, list[float]] = defaultdict(list)

    for item in dividends:
        value = item.get("rate")
        if value is None:
            continue
        ref = normalize_reference_date(item.get("lastDatePrior"))
        paid = normalize_reference_date(item.get("paymentDate"))
        payments.append(
            FiiDistributionPayment(
                reference_date=ref,
                payment_date=paid,
                value_per_share=float(value),
            )
        )
        if ref:
            by_year[int(ref[:4])].append(float(value))

    annual_summary = [
        FiiDistributionYearSummary(
            year=year,
            total_per_share=round(sum(values), 4),
            payments=len(values),
        )
        for year, values in sorted(by_year.items(), reverse=True)
    ]

    ttm_per_share = round(sum(p.value_per_share or 0 for p in payments[:12]), 4) if payments else None

    return FiiDistributions(
        ticker=ticker,
        name=name,
        dividend_yield_ttm=dividend_yield_ttm,
        ttm_per_share=ttm_per_share,
        close_price=close_price,
        total_payments=len(payments),
        annual_summary=annual_summary,
        payments=payments,
        provider="brapi",
    )


def map_history(*, ticker: str, name: str, entries: list[dict]) -> FiiHistoryResponse:
    history: list[FiiHistoryPoint] = []
    for item in entries:
        dy_month = item.get("dividendYield1m")
        history.append(
            FiiHistoryPoint(
                reference_date=normalize_reference_date(item.get("referenceDate")),
                close_price=item.get("price"),
                book_value_per_share=item.get("navPerShare"),
                pvp=item.get("priceToNav"),
                dy_month_pct=pct_from_ratio(dy_month) if dy_month is not None else None,
                net_asset_value=item.get("equity"),
                total_shareholders=item.get("totalInvestors"),
            )
        )

    return FiiHistoryResponse(
        ticker=ticker,
        name=name,
        count=len(history),
        history=history,
        provider="brapi",
    )


def map_candles(*, ticker: str, price_points: list[dict]) -> FiiCandlesResponse:
    candles: list[FiiCandleBar] = []
    for item in price_points:
        ts = item.get("date")
        if ts is None:
            continue
        trade_date = datetime.fromtimestamp(int(ts), tz=UTC).strftime("%Y-%m-%d")
        open_ = item.get("open")
        high = item.get("high")
        low = item.get("low")
        close = item.get("close")
        if None in (open_, high, low, close):
            continue
        candles.append(
            FiiCandleBar(
                trade_date=trade_date,
                open=float(open_),
                high=float(high),
                low=float(low),
                close=float(close),
                volume=float(item["volume"]) if item.get("volume") is not None else None,
            )
        )

    candles.sort(key=lambda bar: bar.trade_date)
    return FiiCandlesResponse(ticker=ticker, count=len(candles), candles=candles, provider="brapi")
