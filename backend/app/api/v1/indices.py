from fastapi import APIRouter, Query

from app.services.indices_service import indices_service

router = APIRouter(prefix="/indices", tags=["indices"])


@router.get("")
async def list_featured_indices():
    """Principais índices — fonte: Brapi."""
    return await indices_service.list_featured()


@router.get("/explore")
async def explore_indices(
    search: str | None = Query(default=None, min_length=1, max_length=32),
    group: str = Query(default="all", pattern=r"^[a-z_]+$"),
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=30, ge=1, le=50),
):
    """Índices paginados — para tela Explorar."""
    return await indices_service.explore(search=search, group=group, page=page, limit=limit)


@router.get("/count")
async def count_indices():
    return {"total": await indices_service.count_indices(), "provider": "brapi"}


@router.get("/{symbol}")
async def get_index_quote(symbol: str):
    """Cotação atual de um índice (ex.: ^BVSP, IFIX)."""
    return await indices_service.get_detail(symbol)


@router.get("/{symbol}/history")
async def get_index_history(
    symbol: str,
    limit: int = Query(default=252, ge=1, le=5000),
):
    """Histórico diário de pontos — fonte: Brapi."""
    return await indices_service.get_history(symbol, limit=limit)
