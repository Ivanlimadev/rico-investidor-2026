from __future__ import annotations

from app.domain.currency.models import (
    CurrencyHistoryPoint,
    CurrencyHistoryResponse,
    CurrencyListResponse,
    CurrencyPairListResponse,
    CurrencyPairSummary,
    CurrencyQuote,
)


def _to_float(value: object | None) -> float | None:
    if value is None or value == "":
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def normalize_currency_pair(raw: str) -> str:
    cleaned = raw.strip().upper().replace("/", "-")
    if not cleaned:
        return cleaned
    parts = cleaned.split("-")
    if len(parts) == 2:
        return f"{parts[0]}-{parts[1]}"
    return cleaned


def map_currency_quote(item: dict) -> CurrencyQuote:
    from_currency = str(item.get("fromCurrency") or "").upper()
    to_currency = str(item.get("toCurrency") or "").upper()
    pair = f"{from_currency}-{to_currency}" if from_currency and to_currency else ""
    return CurrencyQuote(
        pair=pair,
        name=str(item.get("name") or pair),
        from_currency=from_currency,
        to_currency=to_currency,
        bid_price=_to_float(item.get("bidPrice")),
        ask_price=_to_float(item.get("askPrice")),
        high=_to_float(item.get("high")),
        low=_to_float(item.get("low")),
        bid_variation=_to_float(item.get("bidVariation")),
        change_percent=_to_float(item.get("percentageChange")),
        updated_at=item.get("updatedAtDate"),
    )


def map_currency_rates(data: dict) -> CurrencyListResponse:
    items = [map_currency_quote(item) for item in data.get("currency") or [] if isinstance(item, dict)]
    return CurrencyListResponse(items=items, count=len(items))


def map_available_pairs(data: dict) -> CurrencyPairListResponse:
    pairs: list[CurrencyPairSummary] = []
    for item in data.get("currencies") or []:
        if not isinstance(item, dict):
            continue
        pair = normalize_currency_pair(str(item.get("name") or ""))
        if not pair:
            continue
        pairs.append(
            CurrencyPairSummary(
                pair=pair,
                name=str(item.get("currency") or pair),
            )
        )
    return CurrencyPairListResponse(pairs=pairs, count=len(pairs))


def map_currency_history(data: dict, *, pair: str) -> CurrencyHistoryResponse:
    normalized = normalize_currency_pair(pair)
    results = data.get("results") or []
    selected = next(
        (
            item
            for item in results
            if isinstance(item, dict) and normalize_currency_pair(str(item.get("pair") or "")) == normalized
        ),
        None,
    )
    if selected is None and results and isinstance(results[0], dict):
        selected = results[0]

    if not selected:
        return CurrencyHistoryResponse(
            pair=normalized,
            from_currency=normalized.split("-")[0] if "-" in normalized else normalized,
            to_currency=normalized.split("-")[1] if "-" in normalized else "",
            history=[],
            count=0,
        )

    observations = selected.get("observations") or []
    history = [
        CurrencyHistoryPoint(date=str(point.get("date")), value=float(point.get("value")))
        for point in observations
        if isinstance(point, dict) and point.get("date") is not None and point.get("value") is not None
    ]
    history.sort(key=lambda point: point.date)

    return CurrencyHistoryResponse(
        pair=normalize_currency_pair(str(selected.get("pair") or normalized)),
        from_currency=str(selected.get("fromCurrency") or normalized.split("-")[0]).upper(),
        to_currency=str(selected.get("toCurrency") or (normalized.split("-")[1] if "-" in normalized else "")).upper(),
        history=history,
        count=len(history),
    )
