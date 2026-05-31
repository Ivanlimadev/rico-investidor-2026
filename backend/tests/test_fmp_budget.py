import asyncio
from unittest.mock import AsyncMock

from app.config import settings
from app.core.exceptions import UpstreamError
from app.services.global_market_service import GlobalMarketService


class _FakeFmp:
    def __init__(self, behavior):
        self.configured = True
        self.calls = 0
        self._behavior = behavior

    async def get_company_profile(self, symbol):
        self.calls += 1
        return self._behavior(symbol)


def _make_service(monkeypatch, tmp_path, fake_fmp, *, budget=10):
    monkeypatch.setattr(settings, "fmp_cache_dir", tmp_path)
    monkeypatch.setattr(settings, "fmp_daily_request_budget", budget)
    return GlobalMarketService(client=AsyncMock(), fmp_client=fake_fmp)


def test_fmp_profile_cached_in_memory_after_first_call(monkeypatch, tmp_path):
    fake = _FakeFmp(lambda s: {"symbol": s, "sector": "Tech"})
    service = _make_service(monkeypatch, tmp_path, fake)

    first = asyncio.run(service._fetch_fmp_profile("AAPL"))
    second = asyncio.run(service._fetch_fmp_profile("AAPL"))

    assert first == {"symbol": "AAPL", "sector": "Tech"}
    assert second == first
    # Segunda chamada veio do cache — não bateu na rede de novo.
    assert fake.calls == 1


def test_fmp_profile_negative_cache_blocks_repeat(monkeypatch, tmp_path):
    fake = _FakeFmp(lambda s: None)  # símbolo sem perfil
    service = _make_service(monkeypatch, tmp_path, fake)

    assert asyncio.run(service._fetch_fmp_profile("NONE")) is None
    assert asyncio.run(service._fetch_fmp_profile("NONE")) is None
    # Cache negativo evita segunda chamada à API.
    assert fake.calls == 1


def test_fmp_profile_respects_daily_budget(monkeypatch, tmp_path):
    fake = _FakeFmp(lambda s: {"symbol": s})
    service = _make_service(monkeypatch, tmp_path, fake, budget=1)

    asyncio.run(service._fetch_fmp_profile("AAA"))  # consome o único crédito
    result = asyncio.run(service._fetch_fmp_profile("BBB"))  # bloqueado pelo teto

    assert result is None
    assert fake.calls == 1


def test_fmp_profile_transient_error_does_not_poison_negative_cache(monkeypatch, tmp_path):
    def boom(_symbol):
        raise UpstreamError("FMP rate limit", status_code=429)

    fake = _FakeFmp(boom)
    service = _make_service(monkeypatch, tmp_path, fake, budget=10)

    assert asyncio.run(service._fetch_fmp_profile("AAPL")) is None
    # Erro transitório não marca negativo → tenta de novo (consome budget, mas não bloqueia).
    assert asyncio.run(service._fetch_fmp_profile("AAPL")) is None
    assert fake.calls == 2


def test_fmp_profile_persists_to_disk(monkeypatch, tmp_path):
    fake = _FakeFmp(lambda s: {"symbol": s, "sector": "Tech"})
    service = _make_service(monkeypatch, tmp_path, fake)
    asyncio.run(service._fetch_fmp_profile("AAPL"))

    # Novo serviço (simula restart) lê do disco, sem nova chamada de rede.
    fake2 = _FakeFmp(lambda s: {"symbol": s, "sector": "SHOULD-NOT-BE-USED"})
    service2 = _make_service(monkeypatch, tmp_path, fake2)
    result = asyncio.run(service2._fetch_fmp_profile("AAPL"))

    assert result == {"symbol": "AAPL", "sector": "Tech"}
    assert fake2.calls == 0
