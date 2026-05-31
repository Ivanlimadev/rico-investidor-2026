from __future__ import annotations

import hashlib
import json
import time
from datetime import UTC, datetime
from pathlib import Path
from typing import Any


def _safe_name(key: str) -> str:
    return hashlib.sha1(key.encode("utf-8")).hexdigest()


class NegativeCache:
    """Cache negativo em memória: lembra chaves que falharam (ex.: logo 404)
    para não martelar a API de origem repetidamente."""

    def __init__(self, ttl_seconds: int, *, max_entries: int = 8192) -> None:
        self._ttl = ttl_seconds
        self._max_entries = max(64, max_entries)
        self._store: dict[str, float] = {}

    def is_blocked(self, key: str) -> bool:
        expires_at = self._store.get(key)
        if expires_at is None:
            return False
        if time.monotonic() > expires_at:
            self._store.pop(key, None)
            return False
        return True

    def mark(self, key: str) -> None:
        self._store[key] = time.monotonic() + self._ttl
        if len(self._store) > self._max_entries:
            now = time.monotonic()
            stale = [k for k, exp in self._store.items() if exp < now]
            for k in stale:
                self._store.pop(k, None)
            # Se ainda estiver cheio, descarta os mais antigos.
            while len(self._store) > self._max_entries:
                oldest = min(self._store, key=self._store.get)  # type: ignore[arg-type]
                self._store.pop(oldest, None)

    def clear(self) -> None:
        self._store.clear()


class DiskBytesCache:
    """Cache de bytes em disco — persiste entre reinícios. Usado para logos PNG."""

    def __init__(self, directory: Path, *, ttl_seconds: int | None = None) -> None:
        self._dir = Path(directory)
        self._ttl = ttl_seconds
        try:
            self._dir.mkdir(parents=True, exist_ok=True)
        except OSError:
            pass

    def _path(self, key: str) -> Path:
        return self._dir / f"{_safe_name(key)}.bin"

    def get(self, key: str) -> bytes | None:
        path = self._path(key)
        try:
            if not path.exists():
                return None
            if self._ttl is not None and (time.time() - path.stat().st_mtime) > self._ttl:
                return None
            return path.read_bytes()
        except OSError:
            return None

    def set(self, key: str, value: bytes) -> None:
        path = self._path(key)
        tmp = path.with_suffix(".tmp")
        try:
            tmp.write_bytes(value)
            tmp.replace(path)
        except OSError:
            try:
                tmp.unlink(missing_ok=True)
            except OSError:
                pass


class DiskJsonCache:
    """Cache JSON em disco com TTL embutido — persiste perfis FMP entre reinícios."""

    def __init__(self, directory: Path, *, ttl_seconds: int) -> None:
        self._dir = Path(directory)
        self._ttl = ttl_seconds
        try:
            self._dir.mkdir(parents=True, exist_ok=True)
        except OSError:
            pass

    def _path(self, key: str) -> Path:
        return self._dir / f"{_safe_name(key)}.json"

    def get(self, key: str) -> dict | None:
        path = self._path(key)
        try:
            if not path.exists():
                return None
            raw = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return None
        if not isinstance(raw, dict):
            return None
        stored_at = raw.get("_stored_at")
        payload = raw.get("payload")
        if not isinstance(stored_at, (int, float)) or not isinstance(payload, dict):
            return None
        if (time.time() - stored_at) > self._ttl:
            return None
        return payload

    def set(self, key: str, payload: dict) -> None:
        path = self._path(key)
        tmp = path.with_suffix(".tmp")
        body = {"_stored_at": time.time(), "payload": payload}
        try:
            tmp.write_text(json.dumps(body), encoding="utf-8")
            tmp.replace(path)
        except OSError:
            try:
                tmp.unlink(missing_ok=True)
            except OSError:
                pass


class DailyCallBudget:
    """Teto de chamadas por dia (reset à meia-noite UTC), persistido em disco para
    sobreviver a reinícios — protege limites de planos gratuitos (ex.: FMP 250/dia)."""

    def __init__(self, max_calls: int, *, state_path: Path) -> None:
        self._max = max(0, max_calls)
        self._state_path = Path(state_path)
        self._day = self._today()
        self._count = 0
        self._load()

    @staticmethod
    def _today() -> str:
        return datetime.now(UTC).date().isoformat()

    def _load(self) -> None:
        try:
            raw: Any = json.loads(self._state_path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return
        if not isinstance(raw, dict):
            return
        day = raw.get("day")
        count = raw.get("count")
        if isinstance(day, str) and isinstance(count, int):
            self._day = day
            self._count = max(0, count)

    def _persist(self) -> None:
        tmp = self._state_path.with_suffix(".tmp")
        try:
            self._state_path.parent.mkdir(parents=True, exist_ok=True)
            tmp.write_text(json.dumps({"day": self._day, "count": self._count}), encoding="utf-8")
            tmp.replace(self._state_path)
        except OSError:
            pass

    def _rollover(self) -> None:
        today = self._today()
        if today != self._day:
            self._day = today
            self._count = 0

    def allow(self) -> bool:
        self._rollover()
        return self._count < self._max

    def record(self) -> None:
        self._rollover()
        self._count += 1
        self._persist()

    @property
    def remaining(self) -> int:
        self._rollover()
        return max(0, self._max - self._count)
