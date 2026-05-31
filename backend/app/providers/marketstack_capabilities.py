from dataclasses import dataclass
from enum import Enum

from app.config import settings


class MarketstackPlan(str, Enum):
    FREE = "free"
    BASIC = "basic"
    PROFESSIONAL = "professional"
    BUSINESS = "business"


@dataclass(frozen=True)
class MarketstackCapabilities:
    plan: MarketstackPlan
    max_history_days: int
    realtime_enabled: bool
    fundamentals_enabled: bool
    monthly_request_budget: int | None
    eod_only: bool
    intraday_interval: str | None = None

    @property
    def data_mode(self) -> str:
        return "realtime" if self.realtime_enabled else "eod"


_PLAN_DEFAULTS: dict[MarketstackPlan, MarketstackCapabilities] = {
    MarketstackPlan.FREE: MarketstackCapabilities(
        plan=MarketstackPlan.FREE,
        max_history_days=365,
        realtime_enabled=False,
        fundamentals_enabled=False,
        monthly_request_budget=100,
        eod_only=True,
    ),
    MarketstackPlan.BASIC: MarketstackCapabilities(
        plan=MarketstackPlan.BASIC,
        max_history_days=3650,
        realtime_enabled=False,
        fundamentals_enabled=False,
        monthly_request_budget=10_000,
        eod_only=True,
    ),
    MarketstackPlan.PROFESSIONAL: MarketstackCapabilities(
        plan=MarketstackPlan.PROFESSIONAL,
        max_history_days=5475,
        realtime_enabled=True,
        fundamentals_enabled=False,
        monthly_request_budget=100_000,
        eod_only=False,
    ),
    MarketstackPlan.BUSINESS: MarketstackCapabilities(
        plan=MarketstackPlan.BUSINESS,
        max_history_days=5475,
        realtime_enabled=True,
        fundamentals_enabled=True,
        monthly_request_budget=500_000,
        eod_only=False,
        intraday_interval="5min",
    ),
}


_PLAN_ALIASES: dict[str, MarketstackPlan] = {
    "10": MarketstackPlan.BASIC,
    "basic10": MarketstackPlan.BASIC,
    "150": MarketstackPlan.BUSINESS,
    "business150": MarketstackPlan.BUSINESS,
}


def marketstack_capabilities() -> MarketstackCapabilities:
    raw = (settings.marketstack_plan or "basic").strip().lower()
    if raw in _PLAN_ALIASES:
        plan = _PLAN_ALIASES[raw]
    else:
        try:
            plan = MarketstackPlan(raw)
        except ValueError:
            plan = MarketstackPlan.BASIC
    caps = _PLAN_DEFAULTS[plan]
    if caps.realtime_enabled and settings.marketstack_intraday_interval.strip():
        return MarketstackCapabilities(
            plan=caps.plan,
            max_history_days=caps.max_history_days,
            realtime_enabled=caps.realtime_enabled,
            fundamentals_enabled=caps.fundamentals_enabled,
            monthly_request_budget=caps.monthly_request_budget,
            eod_only=caps.eod_only,
            intraday_interval=settings.marketstack_intraday_interval.strip(),
        )
    return caps
