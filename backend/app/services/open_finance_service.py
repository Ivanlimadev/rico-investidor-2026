import re
from datetime import UTC, datetime

from app.clients.pluggy.client import PluggyClient
from app.core.exceptions import AppError
from app.services.open_finance_store import OpenFinanceStore

_TICKER_RE = re.compile(r"\b([A-Z]{4}\d{1,2})\b")


class OpenFinanceService:
    def __init__(
        self,
        client: PluggyClient | None = None,
        store: OpenFinanceStore | None = None,
    ) -> None:
        self._client = client or PluggyClient()
        self._store = store or OpenFinanceStore()

    async def create_connect_token(self, client_user_id: str) -> str:
        client_user_id = client_user_id.strip()
        if not client_user_id:
            raise AppError("client_user_id é obrigatório", status_code=400)
        return await self._client.create_connect_token(client_user_id=client_user_id)

    def register_item(self, client_user_id: str, item_id: str) -> None:
        client_user_id = client_user_id.strip()
        item_id = item_id.strip()
        if not client_user_id or not item_id:
            raise AppError("client_user_id e item_id são obrigatórios", status_code=400)
        self._store.add_item_id(client_user_id, item_id)

    def status(self, client_user_id: str) -> dict:
        item_ids = self._store.list_item_ids(client_user_id)
        return {
            "client_user_id": client_user_id,
            "linked_items": len(item_ids),
            "item_ids": item_ids,
            "provider": "pluggy",
        }

    async def sync_portfolio(self, client_user_id: str) -> dict:
        item_ids = self._store.list_item_ids(client_user_id)
        if not item_ids:
            raise AppError(
                "Nenhuma corretora conectada. Use Conectar investimentos primeiro.",
                status_code=404,
            )

        holdings: list[dict] = []
        institutions: list[str] = []

        for item_id in item_ids:
            item_meta = await self._safe_item_meta(item_id)
            if item_meta:
                institutions.append(item_meta)

            investments = await self._client.list_investments(item_id)
            for investment in investments:
                mapped = _map_investment(investment, institution=item_meta)
                if mapped:
                    holdings.append(mapped)

        return {
            "client_user_id": client_user_id,
            "linked_items": len(item_ids),
            "institutions": sorted(set(institutions)),
            "holdings": holdings,
            "synced_at": datetime.now(UTC).isoformat(),
            "provider": "pluggy",
        }

    async def _safe_item_meta(self, item_id: str) -> str | None:
        try:
            item = await self._client.fetch_item(item_id)
        except Exception:
            return None

        connector = item.get("connector") or {}
        if isinstance(connector, dict):
            name = connector.get("name")
            if isinstance(name, str) and name.strip():
                return name.strip()
        institution = item.get("institution")
        if isinstance(institution, str) and institution.strip():
            return institution.strip()
        return None


def _map_investment(investment: dict, *, institution: str | None) -> dict | None:
    status = (investment.get("status") or "ACTIVE").upper()
    if status not in {"ACTIVE", "PENDING"}:
        return None

    balance = _to_float(investment.get("balance"))
    if balance is None or balance <= 0:
        return None

    name = str(investment.get("name") or "Investimento").strip()
    symbol = _resolve_symbol(investment, name)
    quantity = _to_float(investment.get("quantity")) or 1.0
    if quantity <= 0:
        quantity = 1.0

    unit_value = _to_float(investment.get("value"))
    if unit_value is None or unit_value <= 0:
        unit_value = balance / quantity

    amount_original = _to_float(investment.get("amountOriginal"))
    average_price = amount_original / quantity if amount_original and amount_original > 0 else unit_value

    investment_id = str(investment.get("id") or symbol)
    asset_type = str(investment.get("type") or "OTHER")
    subtype = investment.get("subtype")

    return {
        "id": f"of-{investment_id}",
        "symbol": symbol,
        "name": name,
        "quantity": round(quantity, 6),
        "average_price": round(average_price, 4),
        "current_price": round(unit_value, 4),
        "market_value": round(balance, 2),
        "source": "open_finance",
        "institution": institution,
        "asset_type": asset_type,
        "asset_subtype": subtype,
    }


def _resolve_symbol(investment: dict, name: str) -> str:
    for key in ("code", "isin", "number"):
        raw = investment.get(key)
        if isinstance(raw, str) and raw.strip():
            candidate = raw.strip().upper()
            if key == "code" and _TICKER_RE.fullmatch(candidate):
                return candidate
            if key == "code" and len(candidate) <= 12 and candidate.replace(".", "").isalnum():
                match = _TICKER_RE.search(candidate)
                if match:
                    return match.group(1)

    match = _TICKER_RE.search(name.upper())
    if match:
        return match.group(1)

    slug = re.sub(r"[^A-Z0-9]+", "-", name.upper()).strip("-")
    if len(slug) > 24:
        slug = slug[:24]
    inv_id = str(investment.get("id") or "")[:8]
    return f"{slug or 'ATIVO'}-{inv_id}".upper()


def _to_float(value) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None
