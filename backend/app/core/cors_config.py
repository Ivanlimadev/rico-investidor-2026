import re

from app.config import settings


def _pattern_to_regex(origin: str) -> str:
    """Converte entrada como http://localhost:* em regex de origem."""
    trimmed = origin.strip()
    if not trimmed:
        return ""
    if "*" in trimmed:
        escaped = re.escape(trimmed).replace(r"\*", "[^/]*")
        return escaped
    return re.escape(trimmed)


def build_cors_origin_regex() -> str:
    raw = settings.cors_origins.strip()
    if not raw:
        return r"https?://(localhost|127\.0\.0\.1)(:\d+)?"

    patterns = [_pattern_to_regex(part) for part in raw.split(",") if part.strip()]
    patterns = [p for p in patterns if p]
    if not patterns:
        return r"https?://(localhost|127\.0\.0\.1)(:\d+)?"

    return "|".join(f"({p})" for p in patterns)
