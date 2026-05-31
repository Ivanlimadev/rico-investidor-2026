import time
from collections import OrderedDict
from typing import Generic, TypeVar

T = TypeVar("T")


class TtlCache(Generic[T]):
    def __init__(self, ttl_seconds: int, *, max_entries: int = 512) -> None:
        self._ttl = ttl_seconds
        self._max_entries = max(16, max_entries)
        self._store: OrderedDict[str, tuple[float, T]] = OrderedDict()

    def get(self, key: str) -> T | None:
        entry = self._store.get(key)
        if entry is None:
            return None
        expires_at, value = entry
        if time.monotonic() > expires_at:
            del self._store[key]
            return None
        self._store.move_to_end(key)
        return value

    def set(self, key: str, value: T) -> None:
        self._store[key] = (time.monotonic() + self._ttl, value)
        self._store.move_to_end(key)
        while len(self._store) > self._max_entries:
            self._store.popitem(last=False)

    def clear(self) -> None:
        self._store.clear()


class StaleTtlCache(TtlCache[T]):
    """Cache TTL com fallback para último valor válido (útil quando a API estoura cota)."""

    def __init__(self, ttl_seconds: int, *, max_entries: int = 512) -> None:
        super().__init__(ttl_seconds, max_entries=max_entries)
        self._last_good: dict[str, T] = {}

    def set(self, key: str, value: T) -> None:
        super().set(key, value)
        self._last_good[key] = value

    def get_last_good(self, key: str) -> T | None:
        fresh = self.get(key)
        if fresh is not None:
            return fresh
        return self._last_good.get(key)

    def clear(self) -> None:
        super().clear()
        self._last_good.clear()
