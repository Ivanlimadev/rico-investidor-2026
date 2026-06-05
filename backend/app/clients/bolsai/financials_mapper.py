from __future__ import annotations

from app.clients.brapi.models import FinancialLine, FinancialPeriod, StockFinancialsResponse
from app.clients.brapi.stock_mapper import normalize_financial_period

_INCOME_LINES: tuple[tuple[str, str, str], ...] = (
    ("total_revenue", "Receita líquida", "3.01"),
    ("cost_of_revenue", "CPV", "3.02"),
    ("gross_profit", "Lucro bruto", "3.03"),
    ("operating_income", "Lucro operacional", "3.05"),
    ("income_before_tax", "LAIR", "3.07"),
    ("net_income", "Lucro líquido", "3.11"),
)

_BALANCE_LINES: tuple[tuple[str, str, str, str], ...] = (
    ("total_assets", "Ativo total", "BPA", "1"),
    ("total_current_assets", "Ativo circulante", "BPA", "1.01"),
    ("cash", "Caixa", "BPA", "1.01.01"),
    ("total_liab", "Passivo total", "BPP", "2"),
    ("total_current_liabilities", "Passivo circulante", "BPP", "2.01"),
    ("long_term_debt", "Dívida LP", "BPP", "2.02.01"),
    ("total_stockholder_equity", "Patrimônio líquido", "BPP", "2.03"),
)

_CASH_FLOW_LINES: tuple[tuple[str, str, str], ...] = (
    ("operating_cash_flow", "Caixa operacional", "6.01"),
    ("investment_cash_flow", "Caixa investimento", "6.02"),
    ("financing_cash_flow", "Caixa financiamento", "6.03"),
    ("increase_or_decrease_in_cash", "Variação de caixa", "6.05"),
    ("final_cash_balance", "Saldo final de caixa", "6.05.02"),
)

_DVA_LINES: tuple[tuple[str, str, str], ...] = (
    ("revenue", "Receita", "7.01"),
    ("supplies_purchased", "Insumos adquiridos", "7.02"),
    ("gross_added_value", "Valor adicionado bruto", "7.03"),
    ("depreciation", "Depreciação e amortização", "7.04.01"),
    ("net_added_value", "Valor adicionado líquido", "7.05"),
    ("added_value_to_distribute", "VA total a distribuir", "7.07"),
    ("team_remuneration", "Pessoal", "7.08.01"),
    ("taxes", "Impostos", "7.08.02"),
    ("third_party_capital", "Remuneração cap. terceiros", "7.08.03"),
    ("own_equity_remuneration", "Remuneração cap. próprio", "7.08.04"),
)

_ABS_KEYS = frozenset({"cost_of_revenue", "supplies_purchased", "depreciation"})


def _normalize_value(key: str, value: float | None) -> float | None:
    if value is None:
        return None
    if key in _ABS_KEYS:
        return round(abs(value), 4)
    return round(value, 4)


def _index_statements(statements: list[dict]) -> dict[tuple[str, str, str], float]:
    index: dict[tuple[str, str, str], float] = {}
    for row in statements:
        if not isinstance(row, dict):
            continue
        stype = str(row.get("statement_type") or "").strip()
        date = str(row.get("reference_date") or "").split("T", 1)[0]
        code = str(row.get("account_code") or "").strip()
        raw = row.get("value")
        if not stype or not date or not code or raw is None:
            continue
        try:
            index[(stype, date, code)] = float(raw)
        except (TypeError, ValueError):
            continue
    return index


def _period_dates(
    index: dict[tuple[str, str, str], float],
    *,
    statement_types: set[str],
    limit: int,
) -> list[str]:
    dates = {
        date
        for stype, date, _code in index
        if stype in statement_types and date
    }
    return sorted(dates, reverse=True)[: max(1, limit)]


def _build_periods_3(
    index: dict[tuple[str, str, str], float],
    *,
    dates: list[str],
    statement_type: str,
    line_specs: tuple[tuple[str, str, str], ...],
) -> list[FinancialPeriod]:
    periods: list[FinancialPeriod] = []
    for end_date in dates:
        lines: list[FinancialLine] = []
        for key, label, code in line_specs:
            value = _normalize_value(key, index.get((statement_type, end_date, code)))
            if value is not None:
                lines.append(FinancialLine(key=key, label=label, value=value))
        if lines:
            periods.append(FinancialPeriod(end_date=end_date, lines=lines))
    return periods


def _append_line(period: FinancialPeriod, *, key: str, label: str, value: float | None) -> None:
    if value is None:
        return
    period.lines.append(FinancialLine(key=key, label=label, value=round(value, 4)))


def _build_cash_flow_periods(
    index: dict[tuple[str, str, str], float],
    *,
    dates: list[str],
) -> list[FinancialPeriod]:
    periods = _build_periods_3(
        index,
        dates=dates,
        statement_type="DFC_MI",
        line_specs=_CASH_FLOW_LINES,
    )
    for period in periods:
        operating = index.get(("DFC_MI", period.end_date, "6.01"))
        capex = index.get(("DFC_MI", period.end_date, "6.02.01"))
        if operating is not None and capex is not None:
            _append_line(
                period,
                key="free_cash_flow",
                label="Fluxo de caixa livre",
                value=operating + capex,
            )
    return periods


def _history_metrics_by_date(history_payload: dict | None) -> dict[str, dict[str, float]]:
    if not history_payload:
        return {}
    rows = history_payload.get("history") or history_payload.get("data") or []
    if not isinstance(rows, list):
        return {}
    by_date: dict[str, dict[str, float]] = {}
    for row in rows:
        if not isinstance(row, dict):
            continue
        end = str(row.get("reference_date") or "").split("T", 1)[0]
        if not end:
            continue
        metrics: dict[str, float] = {}
        for key, source in (("ebitda", "ebitda"), ("ebit", "ebit")):
            raw = row.get(source)
            if raw is None:
                continue
            try:
                metrics[key] = float(raw)
            except (TypeError, ValueError):
                continue
        if metrics:
            by_date[end] = metrics
    return by_date


def _enrich_income_with_history(
    periods: list[FinancialPeriod],
    history_payload: dict | None,
) -> list[FinancialPeriod]:
    metrics_by_date = _history_metrics_by_date(history_payload)
    if not metrics_by_date:
        return periods

    enriched: list[FinancialPeriod] = []
    for period in periods:
        metrics = metrics_by_date.get(period.end_date)
        if not metrics:
            enriched.append(period)
            continue
        lines = list(period.lines)
        insert_at = next(
            (idx + 1 for idx, line in enumerate(lines) if line.key == "operating_income"),
            len(lines),
        )
        extra: list[FinancialLine] = []
        if "ebit" in metrics:
            extra.append(FinancialLine(key="ebit", label="EBIT", value=round(metrics["ebit"], 4)))
        if "ebitda" in metrics:
            extra.append(
                FinancialLine(key="ebitda", label="EBITDA", value=round(metrics["ebitda"], 4))
            )
        if extra:
            lines[insert_at:insert_at] = extra
        enriched.append(FinancialPeriod(end_date=period.end_date, lines=lines))
    return enriched


def _build_balance_periods(
    index: dict[tuple[str, str, str], float],
    *,
    dates: list[str],
) -> list[FinancialPeriod]:
    periods: list[FinancialPeriod] = []
    for end_date in dates:
        lines: list[FinancialLine] = []
        for key, label, stype, code in _BALANCE_LINES:
            value = _normalize_value(key, index.get((stype, end_date, code)))
            if value is not None:
                lines.append(FinancialLine(key=key, label=label, value=value))
        if lines:
            periods.append(FinancialPeriod(end_date=end_date, lines=lines))
    return periods


def map_bolsai_financials(
    ticker: str,
    payload: dict,
    *,
    limit: int = 8,
    period: str = "quarterly",
    fundamentals_history: dict | None = None,
) -> StockFinancialsResponse:
    normalized = ticker.upper().strip()
    normalized_period = normalize_financial_period(period)
    statements = payload.get("statements") or []
    if not isinstance(statements, list):
        statements = []

    index = _index_statements(statements)

    income_dates = _period_dates(index, statement_types={"DRE"}, limit=limit)
    cash_dates = _period_dates(index, statement_types={"DFC_MI"}, limit=limit)

    return StockFinancialsResponse(
        ticker=normalized,
        period=normalized_period,
        income_statement=_enrich_income_with_history(
            _build_periods_3(
                index,
                dates=income_dates,
                statement_type="DRE",
                line_specs=_INCOME_LINES,
            ),
            fundamentals_history,
        ),
        balance_sheet=_build_balance_periods(
            index,
            dates=_period_dates(index, statement_types={"BPA", "BPP"}, limit=limit),
        ),
        cash_flow=_build_cash_flow_periods(index, dates=cash_dates),
        value_added=_build_periods_3(
            index,
            dates=_period_dates(index, statement_types={"DVA"}, limit=limit),
            statement_type="DVA",
            line_specs=_DVA_LINES,
        ),
        provider="bolsai",
    )
