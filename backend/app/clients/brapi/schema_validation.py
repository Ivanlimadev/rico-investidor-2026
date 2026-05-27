from __future__ import annotations

from typing import TypeVar

from pydantic import BaseModel, ValidationError

from app.clients.brapi.schemas import (
    BrapiDictionaryResponse,
    BrapiFiiDividendsResponse,
    BrapiFiiHistoricalResponse,
    BrapiFiiHistoryResponse,
    BrapiFiiIndicators,
    BrapiFiiIndicatorsResponse,
    BrapiFiiReportsResponse,
    BrapiCurrencyAvailableResponse,
    BrapiCurrencyHistoricalResponse,
    BrapiCurrencyRatesResponse,
    BrapiInflationResponse,
    BrapiListStock,
    BrapiPrimeRateResponse,
    BrapiQuoteListResponse,
    BrapiQuoteResponse,
    BrapiQuoteResult,
    BrapiTreasuryHistoricalResponse,
    BrapiTreasuryIndicatorsResponse,
    BrapiTreasuryListResponse,
)
from app.core.exceptions import UpstreamError

M = TypeVar("M", bound=BaseModel)


def dump_brapi_item(model: BaseModel) -> dict:
    return model.model_dump(by_alias=True, mode="python")


def parse_brapi_payload(model: type[M], data: object, *, context: str) -> M:
    try:
        return model.model_validate(data)
    except ValidationError as exc:
        raise UpstreamError(
            f"Resposta inválida do provedor ({context})",
            status_code=502,
        ) from exc


def parse_quote_response(data: dict) -> list[dict]:
    envelope = parse_brapi_payload(BrapiQuoteResponse, data, context="quote")
    items: list[dict] = []
    for raw in envelope.results or []:
        if not raw.symbol:
            continue
        items.append(dump_brapi_item(raw))
    return items


def parse_quote_item(data: dict) -> dict:
    items = parse_quote_response(data)
    if not items:
        raise UpstreamError("Ativo não encontrado", status_code=404)
    return items[0]


def parse_quote_list_response(data: dict) -> BrapiQuoteListResponse:
    return parse_brapi_payload(BrapiQuoteListResponse, data, context="quote/list")


def parse_list_stocks(data: dict) -> list[dict]:
    envelope = parse_quote_list_response(data)
    return [
        dump_brapi_item(stock)
        for stock in (envelope.stocks or [])
        if stock.stock
    ]


def parse_fii_indicators_response(data: dict) -> list[dict]:
    envelope = parse_brapi_payload(BrapiFiiIndicatorsResponse, data, context="fii/indicators")
    return [dump_brapi_item(item) for item in (envelope.fiis or []) if item.symbol]


def parse_fii_indicator_item(data: dict) -> dict:
    items = parse_fii_indicators_response(data)
    if not items:
        raise UpstreamError("FII não encontrado", status_code=404)
    return items[0]


def parse_fii_report(data: dict) -> dict | None:
    envelope = parse_brapi_payload(BrapiFiiReportsResponse, data, context="fii/reports")
    reports = envelope.reports or []
    if not reports:
        return None
    return dump_brapi_item(reports[0])


def parse_fii_dividends(data: dict) -> list[dict]:
    envelope = parse_brapi_payload(BrapiFiiDividendsResponse, data, context="fii/dividends")
    return [dump_brapi_item(item) for item in (envelope.dividends or []) if item.symbol]


def parse_fii_history(data: dict) -> list[dict]:
    envelope = parse_brapi_payload(BrapiFiiHistoryResponse, data, context="fii/indicators/history")
    return [dump_brapi_item(item) for item in (envelope.history or []) if item.symbol]


def parse_fii_historical(data: dict) -> list[dict]:
    envelope = parse_brapi_payload(BrapiFiiHistoricalResponse, data, context="fii/historical")
    return [dump_brapi_item(item) for item in (envelope.fiis or []) if item.symbol]


def parse_prime_rate(data: dict) -> dict:
    return dump_brapi_item(parse_brapi_payload(BrapiPrimeRateResponse, data, context="prime-rate"))


def parse_inflation(data: dict) -> dict:
    return dump_brapi_item(parse_brapi_payload(BrapiInflationResponse, data, context="inflation"))


def parse_dictionary(data: dict) -> dict:
    return dump_brapi_item(parse_brapi_payload(BrapiDictionaryResponse, data, context="dictionary"))


def parse_currency_rates(data: dict) -> dict:
    envelope = parse_brapi_payload(BrapiCurrencyRatesResponse, data, context="currency")
    return envelope.model_dump(by_alias=True, mode="python")


def parse_currency_available(data: dict) -> dict:
    envelope = parse_brapi_payload(BrapiCurrencyAvailableResponse, data, context="currency/available")
    return envelope.model_dump(by_alias=True, mode="python")


def parse_currency_historical(data: dict) -> dict:
    envelope = parse_brapi_payload(BrapiCurrencyHistoricalResponse, data, context="currency/historical")
    return envelope.model_dump(by_alias=True, mode="python")


def parse_treasury_list(data: dict) -> dict:
    envelope = parse_brapi_payload(BrapiTreasuryListResponse, data, context="treasury/list")
    return envelope.model_dump(by_alias=True, mode="python")


def parse_treasury_indicators(data: dict) -> dict:
    envelope = parse_brapi_payload(BrapiTreasuryIndicatorsResponse, data, context="treasury/indicators")
    return envelope.model_dump(by_alias=True, mode="python")


def parse_treasury_historical(data: dict) -> dict:
    envelope = parse_brapi_payload(BrapiTreasuryHistoricalResponse, data, context="treasury/indicators/history")
    return envelope.model_dump(by_alias=True, mode="python")


def indicators_by_symbol(items: list[dict]) -> dict[str, dict]:
    result: dict[str, dict] = {}
    for item in items:
        symbol = str(item.get("symbol") or "").upper()
        if symbol:
            result[symbol] = item
    return result
