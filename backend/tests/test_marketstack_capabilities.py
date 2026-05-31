from app.config import settings
from app.providers.marketstack_capabilities import MarketstackPlan, marketstack_capabilities


def test_free_plan_capabilities(monkeypatch):
    monkeypatch.setattr(settings, "marketstack_plan", "free")
    caps = marketstack_capabilities()
    assert caps.plan == MarketstackPlan.FREE
    assert caps.max_history_days == 365
    assert caps.fundamentals_enabled is False
    assert caps.realtime_enabled is False


def test_basic_plan_capabilities(monkeypatch):
    monkeypatch.setattr(settings, "marketstack_plan", "basic")
    caps = marketstack_capabilities()
    assert caps.plan == MarketstackPlan.BASIC
    assert caps.max_history_days == 3650
    assert caps.fundamentals_enabled is False
    assert caps.realtime_enabled is False
    assert caps.monthly_request_budget == 10_000


def test_basic_plan_alias_10(monkeypatch):
    monkeypatch.setattr(settings, "marketstack_plan", "10")
    caps = marketstack_capabilities()
    assert caps.plan == MarketstackPlan.BASIC


def test_business_plan_capabilities(monkeypatch):
    monkeypatch.setattr(settings, "marketstack_plan", "business")
    caps = marketstack_capabilities()
    assert caps.plan == MarketstackPlan.BUSINESS
    assert caps.fundamentals_enabled is True
    assert caps.realtime_enabled is True
