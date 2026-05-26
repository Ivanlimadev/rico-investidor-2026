import re

_FII_TICKER = re.compile(r"^[A-Z]{4}\d{2}$")


def normalize_fii_ticker(raw: str) -> str:
    """Normaliza ticker FII B3 (ex.: hglg11, HGLG → HGLG11)."""
    cleaned = raw.strip().upper().replace(".SA", "")
    if _FII_TICKER.match(cleaned):
        return cleaned
    if len(cleaned) == 4 and cleaned.isalpha():
        return f"{cleaned}11"
    return cleaned


def is_valid_fii_ticker(raw: str) -> bool:
    return bool(_FII_TICKER.match(normalize_fii_ticker(raw)))
