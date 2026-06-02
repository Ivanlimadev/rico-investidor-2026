from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

_BACKEND_ROOT = Path(__file__).resolve().parent.parent
_SECRETS_ENV = Path.home() / "Secrets" / "ricoapp1" / ".env"
_ENV_FILES = (
    _BACKEND_ROOT / ".env",
    _SECRETS_ENV,
    _BACKEND_ROOT / "../../Secrets/ricoapp1/.env",
)


def _resolved_env_files() -> tuple[str, ...]:
    seen: set[Path] = set()
    files: list[str] = []
    for candidate in _ENV_FILES:
        resolved = candidate.resolve()
        if resolved in seen or not resolved.is_file():
            continue
        seen.add(resolved)
        files.append(str(resolved))
    return tuple(files)


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=_resolved_env_files() or (str(_BACKEND_ROOT / ".env"),),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    brapi_api_key: str = ""
    brapi_base_url: str = "https://brapi.dev/api"
    marketstack_api_key: str = ""
    marketstack_base_url: str = "https://api.marketstack.com/v2"
    marketstack_plan: str = "basic"
    marketstack_intraday_interval: str = "5min"
    marketstack_realtime_cache_ttl_seconds: int = 60
    # Financial Modeling Prep — opcional. Plano grátis (250 req/dia) enriquece o
    # perfil de empresas internacionais (descrição, setor, site, etc.).
    fmp_api_key: str = ""
    fmp_base_url: str = "https://financialmodelingprep.com/stable"
    fmp_profile_cache_ttl_seconds: int = 60 * 60 * 24 * 7
    # Teto diário de chamadas FMP (free = 250/dia). Margem de segurança abaixo do limite.
    fmp_daily_request_budget: int = 230
    # Cache negativo: símbolos sem perfil FMP não são re-consultados por este período.
    fmp_negative_cache_ttl_seconds: int = 60 * 60 * 24
    fmp_cache_dir: Path = _BACKEND_ROOT / "data" / "fmp_cache"
    # Logos: cache em disco (sobrevive a restart) + cache negativo (não re-baixa 404).
    logo_cache_dir: Path = _BACKEND_ROOT / "data" / "logo_cache"
    logo_disk_cache_ttl_seconds: int = 60 * 60 * 24 * 30
    logo_memory_cache_ttl_seconds: int = 60 * 60 * 24 * 7
    logo_negative_cache_ttl_seconds: int = 60 * 60 * 12
    logo_memory_max_entries: int = 4096
    logo_http_max_age_seconds: int = 60 * 60 * 24 * 30
    binance_base_url: str = "https://api.binance.com"
    binance_ws_base_url: str = "wss://stream.binance.com:9443"
    coingecko_base_url: str = "https://api.coingecko.com/api/v3"
    coingecko_cache_ttl_seconds: int = 60 * 60 * 6
    crypto_macro_cache_ttl_seconds: int = 60 * 30
    pluggy_client_id: str = ""
    pluggy_client_secret: str = ""
    pluggy_base_url: str = "https://api.pluggy.ai"
    open_finance_api_key: str = ""
    open_finance_store_path: Path = _BACKEND_ROOT / "data" / "open_finance_links.json"
    cors_origins: str = "http://127.0.0.1:*,http://localhost:*"
    rate_limit_per_minute: int = 480
    auth_rate_limit_per_minute: int = 20
    cache_max_entries: int = 512
    fii_fund_catalog_ttl_seconds: int = 3600
    fii_cache_ttl_seconds: int = 900
    quote_cache_ttl_seconds: int = 300
    api_host: str = "127.0.0.1"
    api_port: int = 8000
    auth_secret: str = ""
    auth_token_ttl_seconds: int = 60 * 60 * 24 * 30
    auth_users_path: Path = _BACKEND_ROOT / "data" / "users.json"
    # Swagger/ReDoc/OpenAPI. Em produção use DOCS_ENABLED=false.
    docs_enabled: bool = True


settings = Settings()
