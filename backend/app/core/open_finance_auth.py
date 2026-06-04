from fastapi import Header

from app.config import settings
from app.core.exceptions import AppError


async def require_open_finance_key(
    x_open_finance_key: str | None = Header(default=None, alias="X-Open-Finance-Key"),
) -> None:
    expected = settings.open_finance_api_key.strip()
    if settings.is_production and not expected:
        raise AppError("Open Finance indisponível", status_code=503)

    if not expected:
        return

    if not x_open_finance_key or x_open_finance_key != expected:
        raise AppError("Não autorizado", status_code=401)
