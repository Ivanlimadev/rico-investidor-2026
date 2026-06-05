import pytest

from app.clients.brapi.fii_catalog import _is_fii_listing, parse_screener_params
from app.core.exceptions import AppError


def test_vacancy_filter_parsed_for_bolsai_screener():
    filters = parse_screener_params({"vacancy_pct_lt": "5"})
    assert filters.vacancy_pct_lt == 5.0
    assert filters.needs_indicators is True


def test_is_fii_listing_filters_etfs_without_11_suffix():
    assert _is_fii_listing({"stock": "HGLG11"})
    assert not _is_fii_listing({"stock": "BOVA"})
    assert not _is_fii_listing({"stock": "SMAL"})
    assert not _is_fii_listing({"stock": "BOVV11"})

