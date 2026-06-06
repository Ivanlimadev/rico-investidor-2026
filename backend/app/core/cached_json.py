from typing import Any

from fastapi.encoders import jsonable_encoder
from fastapi.responses import JSONResponse


def cached_json_response(payload: Any, *, max_age_seconds: int) -> JSONResponse:
    """JSON com Cache-Control para leituras estáveis (featured, catálogo, heatmap)."""
    return JSONResponse(
        content=jsonable_encoder(payload),
        headers={"Cache-Control": f"public, max-age={max_age_seconds}"},
    )
