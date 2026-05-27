from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

_BACKEND_ROOT = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(".env", "../../Secrets/ricoapp1/.env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    brapi_api_key: str = ""
    brapi_base_url: str = "https://brapi.dev/api"
    binance_base_url: str = "https://api.binance.com"
    binance_ws_base_url: str = "wss://stream.binance.com:9443"
    pluggy_client_id: str = ""
    pluggy_client_secret: str = ""
    pluggy_base_url: str = "https://api.pluggy.ai"
    open_finance_api_key: str = ""
    open_finance_store_path: Path = _BACKEND_ROOT / "data" / "open_finance_links.json"
    cors_origins: str = "http://127.0.0.1:*,http://localhost:*"
    rate_limit_per_minute: int = 180
    cache_max_entries: int = 512
    fii_fund_catalog_ttl_seconds: int = 3600
    fii_cache_ttl_seconds: int = 900
    quote_cache_ttl_seconds: int = 300
    api_host: str = "127.0.0.1"
    api_port: int = 8000
    auth_secret: str = ""
    auth_token_ttl_seconds: int = 60 * 60 * 24 * 30
    auth_users_path: Path = _BACKEND_ROOT / "data" / "users.json"


settings = Settings()
