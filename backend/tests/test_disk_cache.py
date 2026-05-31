import time

from app.core.disk_cache import (
    DailyCallBudget,
    DiskBytesCache,
    DiskJsonCache,
    NegativeCache,
)


def test_negative_cache_blocks_then_expires():
    cache = NegativeCache(ttl_seconds=0)
    cache.mark("AAPL")
    # TTL 0 → já expirou na próxima checagem.
    assert cache.is_blocked("AAPL") is False
    assert cache.is_blocked("MSFT") is False


def test_negative_cache_active_within_ttl():
    cache = NegativeCache(ttl_seconds=60)
    cache.mark("XYZ")
    assert cache.is_blocked("XYZ") is True
    cache.clear()
    assert cache.is_blocked("XYZ") is False


def test_disk_bytes_cache_roundtrip(tmp_path):
    cache = DiskBytesCache(tmp_path, ttl_seconds=60)
    assert cache.get("nvda") is None
    cache.set("nvda", b"PNGDATA")
    assert cache.get("nvda") == b"PNGDATA"


def test_disk_bytes_cache_respects_ttl(tmp_path):
    cache = DiskBytesCache(tmp_path, ttl_seconds=0)
    cache.set("k", b"data-bytes")
    time.sleep(0.01)
    assert cache.get("k") is None


def test_disk_json_cache_roundtrip(tmp_path):
    cache = DiskJsonCache(tmp_path, ttl_seconds=60)
    payload = {"symbol": "SAP.DE", "sector": "Technology"}
    cache.set("sap", payload)
    assert cache.get("sap") == payload


def test_disk_json_cache_expires(tmp_path):
    cache = DiskJsonCache(tmp_path, ttl_seconds=0)
    cache.set("sap", {"symbol": "SAP.DE"})
    time.sleep(0.01)
    assert cache.get("sap") is None


def test_daily_budget_limits_and_persists(tmp_path):
    state = tmp_path / "budget.json"
    budget = DailyCallBudget(2, state_path=state)

    assert budget.allow() is True
    budget.record()
    assert budget.remaining == 1
    budget.record()
    assert budget.allow() is False
    assert budget.remaining == 0

    # Persistência: nova instância carrega o estado do disco.
    reloaded = DailyCallBudget(2, state_path=state)
    assert reloaded.allow() is False
    assert reloaded.remaining == 0
