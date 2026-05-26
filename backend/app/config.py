from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

_BACKEND_ROOT = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(".env", "../../Secrets/ricoapp1/.env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    bolsai_api_key: str = ""
    bolsai_base_url: str = "https://api.usebolsai.com/api/v1"
    brapi_api_key: str = ""
    brapi_base_url: str = "https://brapi.dev/api"
    pluggy_client_id: str = ""
    pluggy_client_secret: str = ""
    pluggy_base_url: str = "https://api.pluggy.ai"
    open_finance_store_path: Path = _BACKEND_ROOT / "data" / "open_finance_links.json"
    fii_cache_ttl_seconds: int = 900
    quote_cache_ttl_seconds: int = 300
    api_host: str = "0.0.0.0"
    api_port: int = 8000


settings = Settings()
