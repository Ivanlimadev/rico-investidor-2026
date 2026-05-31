from app.services.fii_service import FiiService


def test_fii_search_matches_b3_root_for_klbn4():
    assert FiiService._matches_fii_search("klbn4", "KLBN11", "Klabin FI")
    assert FiiService._matches_fii_search("klbn", "KLBN11", "Klabin FI")
    assert not FiiService._matches_fii_search("vale", "KLBN11", "Klabin FI")


def test_quote_catalog_matches_b3_root():
    from app.services.quote_service import QuoteService

    assert QuoteService._catalog_entry_matches("klbn4", "KLBN3", "Klabin PN")
    assert QuoteService._catalog_entry_matches("klbn", "KLBN4", "Klabin ON")
    assert not QuoteService._catalog_entry_matches("vale", "KLBN4", "Klabin ON")
