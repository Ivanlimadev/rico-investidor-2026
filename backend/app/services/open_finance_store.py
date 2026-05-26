import json
from pathlib import Path

from app.config import settings


class OpenFinanceStore:
    """Persistência simples de vínculos Pluggy (itemId por usuário do app)."""

    def __init__(self, path: Path | None = None) -> None:
        self._path = path or settings.open_finance_store_path
        self._path.parent.mkdir(parents=True, exist_ok=True)

    def _load(self) -> dict[str, dict]:
        if not self._path.exists():
            return {}
        try:
            raw = json.loads(self._path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            return {}
        return raw if isinstance(raw, dict) else {}

    def _save(self, data: dict[str, dict]) -> None:
        self._path.write_text(json.dumps(data, indent=2), encoding="utf-8")

    def list_item_ids(self, client_user_id: str) -> list[str]:
        user = self._load().get(client_user_id) or {}
        items = user.get("item_ids") or []
        return [item for item in items if isinstance(item, str)]

    def add_item_id(self, client_user_id: str, item_id: str) -> None:
        data = self._load()
        user = data.setdefault(client_user_id, {"item_ids": []})
        item_ids: list[str] = list(user.get("item_ids") or [])
        if item_id not in item_ids:
            item_ids.append(item_id)
        user["item_ids"] = item_ids
        self._save(data)
