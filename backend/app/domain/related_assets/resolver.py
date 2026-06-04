from __future__ import annotations

from app.domain.related_assets.presets import INDUSTRY_TO_GROUPS, PEER_GROUPS, SECTOR_TO_GROUPS, TICKER_TO_GROUPS


def _norm(text: str | None) -> str:
    if not text:
        return ""
    return (
        text.strip()
        .lower()
        .replace("á", "a")
        .replace("ã", "a")
        .replace("é", "e")
        .replace("í", "i")
        .replace("ó", "o")
        .replace("ô", "o")
        .replace("ú", "u")
        .replace("ç", "c")
    )


def normalize_ticker(ticker: str) -> str:
    return ticker.upper().strip().replace(".SA", "")


def resolve_peer_candidates(
    ticker: str,
    *,
    market: str,
    sector: str | None = None,
    industry: str | None = None,
    limit: int = 6,
) -> tuple[str, list[tuple[str, str]]]:
    """
    Retorna (subtítulo do grupo, lista de (símbolo, motivo)).
    """
    normalized = normalize_ticker(ticker)
    market_slug = (market or "").strip().lower()

    group_ids: list[str] = []
    seen_ids: set[str] = set()

    def add_ids(ids: tuple[str, ...]) -> None:
        for group_id in ids:
            if group_id in PEER_GROUPS and group_id not in seen_ids:
                seen_ids.add(group_id)
                group_ids.append(group_id)

    add_ids(TICKER_TO_GROUPS.get(normalized, ()))

    if sector:
        add_ids(SECTOR_TO_GROUPS.get(_norm(sector), ()))
    if industry:
        add_ids(INDUSTRY_TO_GROUPS.get(_norm(industry), ()))

    if not group_ids and market_slug in {"stocks", "reits"}:
        add_ids(("us_mag7",))
    if not group_ids and market_slug in {"acoes_br", "bdr", "etf", "etf_br"}:
        add_ids(("br_banks",))
    if not group_ids and market_slug == "cripto":
        add_ids(("crypto_layer1",))

    subtitle_parts = [PEER_GROUPS[gid].label for gid in group_ids[:2]]
    subtitle = " · ".join(subtitle_parts) if subtitle_parts else "Ativos similares"

    peers: list[tuple[str, str]] = []
    seen_symbols: set[str] = {normalized}

    for group_id in group_ids:
        group = PEER_GROUPS[group_id]
        for symbol in group.symbols:
            peer = normalize_ticker(symbol)
            if peer in seen_symbols:
                continue
            seen_symbols.add(peer)
            peers.append((peer, group.label))
            if len(peers) >= limit:
                return subtitle, peers

    return subtitle, peers
